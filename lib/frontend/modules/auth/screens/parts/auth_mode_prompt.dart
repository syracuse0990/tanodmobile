import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/login_screen.dart';

class AuthModePrompt extends StatelessWidget {
  const AuthModePrompt({
    super.key,
    required this.authMode,
    required this.onToggle,
  });

  final AuthMode authMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isLogin = authMode == AuthMode.login;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          isLogin ? 'Don\'t have an account?' : 'Already have an account?',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
        ),
        GestureDetector(
          onTap: onToggle,
          child: Text(
            isLogin ? 'Sign Up' : 'Login',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.pine,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
