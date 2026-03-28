import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffixIcon,
    this.autofocus = false,
    this.enabled = true,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.onFieldSubmitted,
    this.labelStyle,
    this.inputTextStyle,
    this.hintStyle,
    this.fillColor,
    this.prefixIconColor,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onFieldSubmitted;
  final TextStyle? labelStyle;
  final TextStyle? inputTextStyle;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final Color? prefixIconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              labelStyle ??
              Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: inputTextStyle,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          autofocus: autofocus,
          enabled: enabled,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: hintStyle,
            filled: fillColor != null ? true : null,
            fillColor: fillColor,
            prefixIcon: Icon(prefixIcon, color: prefixIconColor),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
