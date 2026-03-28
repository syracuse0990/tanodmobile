import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_text_field.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';

class AuthNameField extends StatelessWidget {
  const AuthNameField({
    super.key,
    required this.controller,
    required this.validator,
    this.lightSurface = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppTextField(
      controller: controller,
      label: 'Full name',
      hint: 'Juan Dela Cruz',
      prefixIcon: Icons.person_outline_rounded,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.name],
      validator: validator,
      labelStyle: _labelStyle(theme, lightSurface: lightSurface),
      inputTextStyle: _fieldTextStyle(theme),
      hintStyle: _hintStyle(theme, lightSurface: lightSurface),
      fillColor: _fillColor(lightSurface: lightSurface),
      prefixIconColor: _iconColor(lightSurface: lightSurface),
    );
  }
}

class AuthLoginField extends StatelessWidget {
  const AuthLoginField({
    super.key,
    required this.controller,
    required this.validator,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.lightSurface = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppTextField(
      controller: controller,
      label: 'Email or Phone Number',
      hint: 'name@company.com or 09XX XXX XXXX',
      prefixIcon: Icons.person_outline_rounded,
      keyboardType: TextInputType.text,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      labelStyle: _labelStyle(theme, lightSurface: lightSurface),
      inputTextStyle: _fieldTextStyle(theme),
      hintStyle: _hintStyle(theme, lightSurface: lightSurface),
      fillColor: _fillColor(lightSurface: lightSurface),
      prefixIconColor: _iconColor(lightSurface: lightSurface),
    );
  }
}

class AuthEmailField extends StatelessWidget {
  const AuthEmailField({
    super.key,
    required this.controller,
    required this.validator,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.lightSurface = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppTextField(
      controller: controller,
      label: 'Email address',
      hint: 'name@company.com',
      prefixIcon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      labelStyle: _labelStyle(theme, lightSurface: lightSurface),
      inputTextStyle: _fieldTextStyle(theme),
      hintStyle: _hintStyle(theme, lightSurface: lightSurface),
      fillColor: _fillColor(lightSurface: lightSurface),
      prefixIconColor: _iconColor(lightSurface: lightSurface),
    );
  }
}

class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscureText,
    required this.onToggleVisibility,
    required this.validator,
    required this.textInputAction,
    this.prefixIcon = Icons.lock_outline_rounded,
    this.autofillHints,
    this.onFieldSubmitted,
    this.lightSurface = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;
  final IconData prefixIcon;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      prefixIcon: prefixIcon,
      obscureText: obscureText,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      labelStyle: _labelStyle(theme, lightSurface: lightSurface),
      inputTextStyle: _fieldTextStyle(theme),
      hintStyle: _hintStyle(theme, lightSurface: lightSurface),
      fillColor: _fillColor(lightSurface: lightSurface),
      prefixIconColor: _iconColor(lightSurface: lightSurface),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(
          obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          color: _iconColor(lightSurface: lightSurface),
        ),
      ),
    );
  }
}

class AuthRoleDropdown extends StatelessWidget {
  const AuthRoleDropdown({
    super.key,
    required this.roles,
    required this.initialValue,
    required this.isLoading,
    required this.onChanged,
    this.lightSurface = false,
  });

  final List<RegistrationRole> roles;
  final String? initialValue;
  final bool isLoading;
  final ValueChanged<String?> onChanged;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role', style: _labelStyle(theme, lightSurface: lightSurface)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(initialValue ?? 'empty-role'),
          initialValue: initialValue,
          items: roles
              .map(
                (role) => DropdownMenuItem<String>(
                  value: role.name,
                  child: Text(role.label),
                ),
              )
              .toList(growable: false),
          onChanged: isLoading ? null : onChanged,
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Choose a role.';
            }

            return null;
          },
          style: _fieldTextStyle(theme),
          dropdownColor: Colors.white,
          iconEnabledColor: _iconColor(lightSurface: lightSurface),
          decoration: InputDecoration(
            hintText: isLoading ? 'Loading roles...' : 'Choose your role',
            hintStyle: _hintStyle(theme, lightSurface: lightSurface),
            filled: true,
            fillColor: _fillColor(lightSurface: lightSurface),
            prefixIcon: Icon(
              Icons.badge_outlined,
              color: _iconColor(lightSurface: lightSurface),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthRoleDescription extends StatelessWidget {
  const AuthRoleDescription({
    super.key,
    required this.description,
    this.lightSurface = false,
  });

  final String description;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightSurface
            ? AppColors.canvas
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: lightSurface
              ? AppColors.forest.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        description,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: lightSurface
              ? AppColors.ink
              : Colors.white.withValues(alpha: 0.88),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

TextStyle? _labelStyle(ThemeData theme, {required bool lightSurface}) {
  return theme.textTheme.labelLarge?.copyWith(
    color: lightSurface ? AppColors.ink : Colors.white.withValues(alpha: 0.92),
    fontWeight: FontWeight.w600,
  );
}

TextStyle? _fieldTextStyle(ThemeData theme) {
  return theme.textTheme.bodyLarge?.copyWith(
    color: AppColors.ink,
    fontWeight: FontWeight.w600,
  );
}

TextStyle? _hintStyle(ThemeData theme, {required bool lightSurface}) {
  return theme.textTheme.bodyMedium?.copyWith(
    color: lightSurface
        ? AppColors.mutedInk.withValues(alpha: 0.86)
        : AppColors.mutedInk.withValues(alpha: 0.85),
  );
}

Color _fillColor({required bool lightSurface}) {
  return lightSurface
      ? const Color(0xFFF7F5F1)
      : Colors.white.withValues(alpha: 0.96);
}

Color _iconColor({required bool lightSurface}) {
  return lightSurface ? AppColors.moss : AppColors.pine;
}
