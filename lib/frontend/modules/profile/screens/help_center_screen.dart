import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await context.read<ApiClient>().get('/help-center');
      final raw = response['contacts'] as List<dynamic>? ?? [];
      setState(() {
        _contacts = raw.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = context.tr('error');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isFarmer = user?.roles.contains('farmer') ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
        slivers: [
          // ─── AppBar ───
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/account'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.forest, AppColors.pine],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr('help_center'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('help_center_subtitle'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Content ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7F6),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.forest,
                          ),
                        ),
                      )
                    : _error != null
                        ? _buildError()
                        : _buildContent(isFarmer),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48,
                color: AppColors.mutedInk.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.mutedInk)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchContacts,
              child: Text(context.tr('retry'),
                  style: const TextStyle(color: AppColors.forest)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isFarmer) {
    final fcaContacts =
        _contacts.where((c) => c['type'] == 'fca').toList();
    final tpsContacts =
        _contacts.where((c) => c['type'] == 'tps').toList();
    final adminContacts =
        _contacts.where((c) => c['type'] == 'admin').toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FCA section (farmers only)
          if (isFarmer && fcaContacts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.admin_panel_settings_rounded,
              title: context.tr('your_fca'),
              color: AppColors.pine,
            ),
            const SizedBox(height: 10),
            ...fcaContacts.map((c) => _ContactCard(
                  contact: c,
                  accentColor: AppColors.pine,
                  roleLabel: context.tr('fca_label'),
                )),
            const SizedBox(height: 24),
          ],

          // TPS section (farmers only)
          if (isFarmer && tpsContacts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.build_circle_rounded,
              title: context.tr('assigned_tps'),
              color: AppColors.moss,
            ),
            const SizedBox(height: 10),
            ...tpsContacts.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ContactCard(
                    contact: c,
                    accentColor: AppColors.moss,
                    roleLabel: context.tr('tps_label'),
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // System Admin
          if (adminContacts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.headset_mic_rounded,
              title: context.tr('system_support'),
              color: AppColors.gold,
            ),
            const SizedBox(height: 10),
            ...adminContacts.map((c) => _ContactCard(
                  contact: c,
                  accentColor: AppColors.gold,
                  roleLabel: context.tr('admin_label'),
                )),
          ],

          const SizedBox(height: 32),

          // Quick help section
          _SectionHeader(
            icon: Icons.lightbulb_outline_rounded,
            title: context.tr('quick_help'),
            color: AppColors.clay,
          ),
          const SizedBox(height: 10),
          _QuickHelpCard(
            icon: Icons.confirmation_num_outlined,
            title: context.tr('help_tickets_title'),
            description: context.tr('help_tickets_desc'),
          ),
          const SizedBox(height: 10),
          _QuickHelpCard(
            icon: Icons.phone_in_talk_rounded,
            title: context.tr('help_call_title'),
            description: context.tr('help_call_desc'),
          ),
          const SizedBox(height: 10),
          _QuickHelpCard(
            icon: Icons.schedule_rounded,
            title: context.tr('help_hours_title'),
            description: context.tr('help_hours_desc'),
          ),

          const SizedBox(height: 32),

          // FAQ section
          _SectionHeader(
            icon: Icons.quiz_rounded,
            title: context.tr('faq_title'),
            color: AppColors.forest,
          ),
          const SizedBox(height: 10),
          _FaqItem(
            question: context.tr('faq_q1'),
            answer: context.tr('faq_a1'),
          ),
          _FaqItem(
            question: context.tr('faq_q2'),
            answer: context.tr('faq_a2'),
          ),
          _FaqItem(
            question: context.tr('faq_q3'),
            answer: context.tr('faq_a3'),
          ),
          _FaqItem(
            question: context.tr('faq_q4'),
            answer: context.tr('faq_a4'),
          ),
          _FaqItem(
            question: context.tr('faq_q5'),
            answer: context.tr('faq_a5'),
          ),
          _FaqItem(
            question: context.tr('faq_q6'),
            answer: context.tr('faq_a6'),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink.withValues(alpha: 0.8),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─── FAQ Item ───

class _FaqItem extends StatefulWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.forest.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        size: 16,
                        color: AppColors.pine,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.question,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 22,
                        color: AppColors.mutedInk.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12, left: 34),
                    child: Text(
                      widget.answer,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.mutedInk.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Contact Card ───

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.accentColor,
    required this.roleLabel,
  });

  final Map<String, dynamic> contact;
  final Color accentColor;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ?? '';
    final email = contact['email'] as String? ?? '';
    final phone = contact['phone'] as String? ?? '';
    final photoUrl = contact['profile_photo_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                  width: 2,
                ),
                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl == null
                  ? Center(
                      child: Text(
                        _initials(name),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (phone.isNotEmpty)
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      text: phone,
                      color: accentColor,
                    ),
                  if (email.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _InfoRow(
                        icon: Icons.email_rounded,
                        text: email,
                        color: accentColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedInk.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Quick Help Card ───

class _QuickHelpCard extends StatelessWidget {
  const _QuickHelpCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.pine),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedInk.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
