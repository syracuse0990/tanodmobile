import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class RememberForgotRow extends StatelessWidget {
  const RememberForgotRow({
    super.key,
    required this.rememberMe,
    required this.onChanged,
  });

  final bool rememberMe;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: rememberMe,
            onChanged: (v) => onChanged(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            side: BorderSide(color: AppColors.mutedInk.withValues(alpha: 0.5)),
            activeColor: AppColors.pine,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Remember Me',
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: Text(
            'Forgot Password?',
            style: style?.copyWith(
              color: AppColors.clay,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
