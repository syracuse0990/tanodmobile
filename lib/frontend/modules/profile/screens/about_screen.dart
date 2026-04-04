import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
        slivers: [
          // ─── AppBar with Hero ───
          SliverAppBar(
            expandedHeight: 220,
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
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/logos/ic_launcher.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TanodTractor',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    context.tr('about_tagline'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Body ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7F6),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Mission ───
                      _ContentCard(
                        icon: Icons.track_changes_rounded,
                        title: context.tr('about_mission_title'),
                        body: context.tr('about_mission_body'),
                        accentColor: AppColors.pine,
                      ),

                      const SizedBox(height: 16),

                      // ─── What is TanodTractor ───
                      _ContentCard(
                        icon: Icons.info_outline_rounded,
                        title: context.tr('about_what_title'),
                        body: context.tr('about_what_body'),
                        accentColor: AppColors.forest,
                      ),

                      const SizedBox(height: 24),

                      // ─── Partnership Section ───
                      _SectionLabel(text: context.tr('about_partners_title')),

                      const SizedBox(height: 12),

                      _PartnerCard(
                        name: 'Leads Agricultural Products Corporation',
                        shortName: 'Leads Agri',
                        description: context.tr('partner_leads_desc'),
                        imagePath: 'assets/images/leads_agri.png',
                        color: AppColors.pine,
                      ),
                      const SizedBox(height: 10),
                      _PartnerCard(
                        name:
                            'Philippine Center for Postharvest Development and Mechanization',
                        shortName: 'PHilMech',
                        description: context.tr('partner_philmech_desc'),
                        imagePath: 'assets/images/philmechs.png',
                        color: AppColors.moss,
                        imagePadding: 2,
                      ),
                      const SizedBox(height: 10),
                      _PartnerCard(
                        name: 'Department of Agriculture',
                        shortName: 'DA',
                        description: context.tr('partner_da_desc'),
                        imagePath: 'assets/images/deptAgri.png',
                        color: AppColors.gold,
                      ),

                      const SizedBox(height: 24),

                      // ─── Key Features ───
                      _SectionLabel(text: context.tr('about_features_title')),
                      const SizedBox(height: 12),

                      _FeatureRow(
                        icon: Icons.gps_fixed_rounded,
                        text: context.tr('feature_tracking'),
                      ),
                      _FeatureRow(
                        icon: Icons.calendar_month_rounded,
                        text: context.tr('feature_booking'),
                      ),
                      _FeatureRow(
                        icon: Icons.build_circle_rounded,
                        text: context.tr('feature_maintenance'),
                      ),
                      _FeatureRow(
                        icon: Icons.fence_rounded,
                        text: context.tr('feature_geofence'),
                      ),
                      _FeatureRow(
                        icon: Icons.assessment_rounded,
                        text: context.tr('feature_reports'),
                      ),
                      _FeatureRow(
                        icon: Icons.notifications_active_rounded,
                        text: context.tr('feature_alerts'),
                      ),

                      const SizedBox(height: 28),

                      // ─── Footer ───
                      Center(
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/logos/ic_launcher.png',
                                width: 40,
                                height: 40,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('about_footer'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppColors.mutedInk.withValues(alpha: 0.5),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

// ─── Section Label ───

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.mutedInk.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Content Card ───

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.mutedInk.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Partner Card ───

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.name,
    required this.shortName,
    required this.description,
    required this.imagePath,
    required this.color,
    this.imagePadding = 0,
  });

  final String name;
  final String shortName;
  final String description;
  final String imagePath;
  final Color color;
  final double imagePadding;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.all(imagePadding),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shortName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedInk.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.mutedInk.withValues(alpha: 0.8),
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

// ─── Feature Row ───

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.pine),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
