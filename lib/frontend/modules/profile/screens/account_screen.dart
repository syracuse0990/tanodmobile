import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/locale_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/elegant_dialog.dart';
import 'package:tanodmobile/frontend/shared/widgets/language_picker.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
        slivers: [
          // ─── Profile Header ───
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.forest, AppColors.pine],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 3,
                          ),
                          image: user?.profilePhotoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(user!.profilePhotoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user?.profilePhotoUrl != null
                            ? null
                            : Center(
                                child: Text(
                                  _initials(user?.name ?? 'U'),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user?.name ?? 'Tanod User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (user?.roles.isNotEmpty == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            user!.roles.first.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Menu Sections ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account section
                      _SectionTitle(title: context.tr('section_account')),
                      const SizedBox(height: 8),
                      _MenuGroup(
                        items: [
                          _MenuItem(
                            icon: Icons.person_outline_rounded,
                            label: context.tr('edit_profile'),
                            onTap: () => context.go('/account/edit-profile'),
                          ),
                          _MenuItem(
                            icon: Icons.lock_outline_rounded,
                            label: context.tr('change_password'),
                            onTap: () => context.go('/account/change-password'),
                          ),
                          _MenuItem(
                            icon: Icons.phone_android_rounded,
                            label: context.tr('phone_number'),
                            subtitle: user?.phoneVerifiedAt != null
                                ? context.tr('verified')
                                : context.tr('not_verified'),
                            onTap: () =>
                                context.go('/account/phone-verification'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _SectionTitle(title: context.tr('section_services')),
                      const SizedBox(height: 8),
                      _MenuGroup(
                        items: [
                          if (user == null || !user.roles.contains('tps'))
                            _MenuItem(
                              icon: Icons.confirmation_num_outlined,
                              label: context.tr('tickets'),
                              onTap: () => context.go('/account/tickets'),
                            ),
                          if (user != null &&
                              user.roles.contains('fca'))
                            _MenuItem(
                              icon: Icons.build_outlined,
                              label: context.tr('maintenance'),
                              onTap: () =>
                                  context.go('/account/maintenance'),
                            ),
                          if (user != null &&
                              user.roles.contains('fca'))
                            _MenuItem(
                              icon: Icons.fence_rounded,
                              label: context.tr('geo_fences'),
                              onTap: () =>
                                  context.go('/account/geofences'),
                            ),
                          if (user == null || !user.roles.contains('tps'))
                            _MenuItem(
                              icon: Icons.rate_review_outlined,
                              label: context.tr('feedback'),
                              onTap: () =>
                                  context.go('/account/feedback'),
                            ),
                          _MenuItem(
                            icon: Icons.assessment_outlined,
                            label: context.tr('reports'),
                            onTap: () =>
                                context.go('/account/reports'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _SectionTitle(title: context.tr('section_support')),
                      const SizedBox(height: 8),
                      _MenuGroup(
                        items: [
                          _MenuItem(
                            icon: Icons.language_rounded,
                            label: context.tr('language'),
                            subtitle: localeProvider.displayName,
                            onTap: () => showLanguagePicker(context),
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            label: context.tr('help_center'),
                            onTap: () => context.go('/account/help-center'),
                          ),
                          _MenuItem(
                            icon: Icons.info_outline_rounded,
                            label: context.tr('about_tanod'),
                            onTap: () => context.go('/account/about'),
                          ),
                          _MenuItem(
                            icon: Icons.description_outlined,
                            label: context.tr('terms_privacy'),
                            onTap: () => context.go('/account/terms-privacy'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Danger zone section
                      _SectionTitle(title: context.tr('delete_account_title').toUpperCase()),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.1),
                          ),
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
                            onTap: () =>
                                context.go('/account/delete-account'),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.danger
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      context.tr('delete_account'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color:
                                        AppColors.danger.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign Out button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ElegantDialog.show(
                              context,
                              type: ElegantDialogType.confirmation,
                              title: context.tr('sign_out'),
                              message: context.tr('sign_out_message'),
                              confirmText: context.tr('sign_out'),
                              onConfirm: authProvider.signOut,
                            );
                          },
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: Text(context.tr('sign_out')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          context.tr('app_version'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedInk.withValues(alpha: 0.6),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: AppColors.ink.withValues(alpha: 0.04),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
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
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedInk,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedInk.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
