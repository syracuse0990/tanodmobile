import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 180,
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
                      padding: const EdgeInsets.fromLTRB(24, 56, 24, 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('terms_privacy'),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.tr('tp_subtitle'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7F6),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: TabBar(
                    labelColor: AppColors.forest,
                    unselectedLabelColor:
                        AppColors.mutedInk.withValues(alpha: 0.5),
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    indicatorColor: AppColors.forest,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerHeight: 0,
                    tabs: [
                      Tab(text: context.tr('tp_tab_terms')),
                      Tab(text: context.tr('tp_tab_privacy')),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _TermsOfServiceTab(),
              _PrivacyPolicyTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════
//  TERMS OF SERVICE TAB
// ═════════════════════════════════════════════════════

class _TermsOfServiceTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Effective date badge
        _EffectiveDateBadge(text: context.tr('tp_effective_date')),
        const SizedBox(height: 16),

        // 1. Acceptance
        _LegalSection(
          number: '1',
          title: context.tr('tos_1_title'),
          body: context.tr('tos_1_body'),
        ),

        // 2. Eligibility
        _LegalSection(
          number: '2',
          title: context.tr('tos_2_title'),
          body: context.tr('tos_2_body'),
        ),

        // 3. Account Responsibilities
        _LegalSection(
          number: '3',
          title: context.tr('tos_3_title'),
          body: context.tr('tos_3_body'),
        ),

        // 4. Use of the Service
        _LegalSection(
          number: '4',
          title: context.tr('tos_4_title'),
          body: context.tr('tos_4_body'),
        ),

        // 5. GPS & Location Data
        _LegalSection(
          number: '5',
          title: context.tr('tos_5_title'),
          body: context.tr('tos_5_body'),
        ),

        // 6. Intellectual Property
        _LegalSection(
          number: '6',
          title: context.tr('tos_6_title'),
          body: context.tr('tos_6_body'),
        ),

        // 7. Limitation of Liability
        _LegalSection(
          number: '7',
          title: context.tr('tos_7_title'),
          body: context.tr('tos_7_body'),
        ),

        // 8. Termination
        _LegalSection(
          number: '8',
          title: context.tr('tos_8_title'),
          body: context.tr('tos_8_body'),
        ),

        // 9. Governing Law
        _LegalSection(
          number: '9',
          title: context.tr('tos_9_title'),
          body: context.tr('tos_9_body'),
        ),

        // 10. Changes to Terms
        _LegalSection(
          number: '10',
          title: context.tr('tos_10_title'),
          body: context.tr('tos_10_body'),
        ),

        const SizedBox(height: 16),
        _ContactFooter(text: context.tr('tp_contact_footer')),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════
//  PRIVACY POLICY TAB
// ═════════════════════════════════════════════════════

class _PrivacyPolicyTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _EffectiveDateBadge(text: context.tr('tp_effective_date')),
        const SizedBox(height: 16),

        // 1. Information We Collect
        _LegalSection(
          number: '1',
          title: context.tr('pp_1_title'),
          body: context.tr('pp_1_body'),
        ),

        // 2. How We Use Your Information
        _LegalSection(
          number: '2',
          title: context.tr('pp_2_title'),
          body: context.tr('pp_2_body'),
        ),

        // 3. Data Sharing & Disclosure
        _LegalSection(
          number: '3',
          title: context.tr('pp_3_title'),
          body: context.tr('pp_3_body'),
        ),

        // 4. Data Retention
        _LegalSection(
          number: '4',
          title: context.tr('pp_4_title'),
          body: context.tr('pp_4_body'),
        ),

        // 5. Data Security
        _LegalSection(
          number: '5',
          title: context.tr('pp_5_title'),
          body: context.tr('pp_5_body'),
        ),

        // 6. Your Rights (Philippine DPA)
        _LegalSection(
          number: '6',
          title: context.tr('pp_6_title'),
          body: context.tr('pp_6_body'),
        ),

        // 7. Children's Privacy
        _LegalSection(
          number: '7',
          title: context.tr('pp_7_title'),
          body: context.tr('pp_7_body'),
        ),

        // 8. Third-Party Services
        _LegalSection(
          number: '8',
          title: context.tr('pp_8_title'),
          body: context.tr('pp_8_body'),
        ),

        // 9. Changes to This Policy
        _LegalSection(
          number: '9',
          title: context.tr('pp_9_title'),
          body: context.tr('pp_9_body'),
        ),

        // 10. Contact Us
        _LegalSection(
          number: '10',
          title: context.tr('pp_10_title'),
          body: context.tr('pp_10_body'),
        ),

        const SizedBox(height: 16),
        _ContactFooter(text: context.tr('tp_contact_footer')),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═════════════════════════════════════════════════════

class _EffectiveDateBadge extends StatelessWidget {
  const _EffectiveDateBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.pine.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.pine.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: AppColors.pine.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pine.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  color: AppColors.mutedInk.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactFooter extends StatelessWidget {
  const _ContactFooter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: AppColors.gold.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.mutedInk.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
