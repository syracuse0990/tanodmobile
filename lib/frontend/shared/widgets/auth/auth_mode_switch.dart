import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.isLoginSelected,
    required this.onLoginTap,
    required this.onSignupTap,
    this.backgroundColor,
    this.borderColor,
    this.selectedBackgroundColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.selectedShadowColor,
  });

  final bool isLoginSelected;
  final VoidCallback onLoginTap;
  final VoidCallback onSignupTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final Color? selectedShadowColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? Colors.white.withValues(alpha: 0.10);
    final effectiveBorderColor =
        borderColor ?? Colors.white.withValues(alpha: 0.08);
    final effectiveSelectedBackgroundColor =
        selectedBackgroundColor ?? Colors.white;
    final effectiveSelectedTextColor = selectedTextColor ?? AppColors.forest;
    final effectiveUnselectedTextColor = unselectedTextColor ?? Colors.white;
    final effectiveSelectedShadowColor =
        selectedShadowColor ?? Colors.black.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: effectiveBorderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeButton(
              label: 'Login',
              selected: isLoginSelected,
              onTap: onLoginTap,
              selectedBackgroundColor: effectiveSelectedBackgroundColor,
              selectedTextColor: effectiveSelectedTextColor,
              unselectedTextColor: effectiveUnselectedTextColor,
              selectedShadowColor: effectiveSelectedShadowColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AuthModeButton(
              label: 'Signup',
              selected: !isLoginSelected,
              onTap: onSignupTap,
              selectedBackgroundColor: effectiveSelectedBackgroundColor,
              selectedTextColor: effectiveSelectedTextColor,
              unselectedTextColor: effectiveUnselectedTextColor,
              selectedShadowColor: effectiveSelectedShadowColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedBackgroundColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    required this.selectedShadowColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBackgroundColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final Color selectedShadowColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? selectedBackgroundColor : Colors.transparent,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedShadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: selected ? selectedTextColor : unselectedTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
