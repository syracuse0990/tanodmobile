import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';

class AuthFormActions {
  const AuthFormActions._();

  static Future<void> submitLogin({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController loginController,
    required TextEditingController passwordController,
  }) async {
    final formState = formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      login: loginController.text.trim(),
      password: passwordController.text,
    );

    if (!context.mounted || success) {
      return;
    }

    _showErrorSnackBar(
      context,
      authProvider.errorMessage ?? 'Unable to sign in.',
    );
  }

  static Future<void> submitSignUp({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required String selectedRoleName,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required TextEditingController passwordConfirmationController,
    TextEditingController? coopNameController,
    TextEditingController? phoneController,
  }) async {
    final formState = formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final phone = phoneController?.text.trim() ?? '';
    if (email.isEmpty && phone.isEmpty) {
      AppToast.error('Please provide either an email or mobile number.');
      return;
    }

    if (phone.isNotEmpty && !RegExp(r'^09\d{9}$').hasMatch(phone)) {
      AppToast.error('Mobile number must start with 09 and be 11 digits.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      role: selectedRoleName,
      name: nameController.text.trim(),
      email: email,
      password: passwordController.text,
      passwordConfirmation: passwordConfirmationController.text,
      coopName: coopNameController?.text.trim(),
      phone: phone.isNotEmpty ? phone : null,
    );

    if (!context.mounted || success) {
      return;
    }

    _showErrorSnackBar(
      context,
      authProvider.errorMessage ?? 'Unable to create your account.',
    );
  }

  static String? validateLoginCredential(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Email or phone number is required.';
    }

    final isEmail = input.contains('@') && input.contains('.');
    final isPhone = RegExp(r'^\+?[\d\s\-]{7,15}$').hasMatch(input);

    return (isEmail || isPhone)
        ? null
        : 'Enter a valid email or phone number.';
  }

  static String? validateEmail(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Email is required.';
    }

    final hasValidShape = input.contains('@') && input.contains('.');

    return hasValidShape ? null : 'Enter a valid email address.';
  }


  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
