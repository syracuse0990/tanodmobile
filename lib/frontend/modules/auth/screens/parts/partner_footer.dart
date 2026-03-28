import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class PartnerFooter extends StatelessWidget {
  const PartnerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedInk.withValues(alpha: 0.6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // DA / PhilMech
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/philmech.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(height: 32, width: 32),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEPARTMENT OF',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'AGRICULTURE',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    width: 1,
                    height: 28,
                    color: Colors.grey.shade300,
                  ),
                ),
                // LeadsAgri
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/leads_agri.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(height: 32, width: 32),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leads',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          'Agri',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '© 2026 TanodTractor · Department of Agriculture · LAPC Program',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: muted),
            ),
            const SizedBox(height: 2),
            Text(
              'Powered by PHilMech & LeadsAgri',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 7, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
