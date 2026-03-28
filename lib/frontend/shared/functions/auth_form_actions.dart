import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';

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
    required String? selectedRoleName,
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required TextEditingController passwordConfirmationController,
  }) async {
    final formState = formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final role = selectedRoleName;

    if (role == null || role.isEmpty) {
      _showErrorSnackBar(context, 'Please choose a role first.');
      return;
    }

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUp(
      role: role,
      name: nameController.text.trim(),
      email: emailController.text.trim(),
      password: passwordController.text,
      passwordConfirmation: passwordConfirmationController.text,
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

  static RegistrationRole? resolveSelectedRole({
    required List<RegistrationRole> roles,
    required String? selectedRoleName,
  }) {
    if (roles.isEmpty) {
      return null;
    }

    for (final role in roles) {
      if (role.name == selectedRoleName) {
        return role;
      }
    }

    return roles.first;
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
