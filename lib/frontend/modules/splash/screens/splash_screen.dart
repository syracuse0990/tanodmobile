import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/widgets/app_shell.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AppShell(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: AppColors.forest,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: 0.16),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'T',
                  style: textTheme.displayMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text('Tanod Mobile', style: textTheme.headlineLarge),
              const SizedBox(height: 10),
              Text('Operations at a glance.', style: textTheme.bodyLarge),
              const SizedBox(height: 28),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
