import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/auth_error_banner.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/auth_mode_prompt.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/decorative_orb.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/hero_content.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/partner_footer.dart';
import 'package:tanodmobile/frontend/modules/auth/screens/parts/remember_forgot_row.dart';
import 'package:tanodmobile/frontend/shared/functions/auth_form_actions.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/auth/auth_fields.dart';
import 'package:tanodmobile/frontend/shared/widgets/primary_button.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';

enum AuthMode { login, signup }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  late final TextEditingController _loginController;
  late final TextEditingController _passwordController;
  late final TextEditingController _signupNameController;
  late final TextEditingController _signupEmailController;
  late final TextEditingController _signupPasswordController;
  late final TextEditingController _signupConfirmPasswordController;

  AuthMode _authMode = AuthMode.login;
  bool _showLoginPassword = false;
  bool _showSignupPassword = false;
  bool _showConfirmPassword = false;
  bool _rememberMe = false;
  String? _selectedRoleName;

  @override
  void initState() {
    super.initState();
    _loginController = TextEditingController();
    _passwordController = TextEditingController();
    _signupNameController = TextEditingController();
    _signupEmailController = TextEditingController();
    _signupPasswordController = TextEditingController();
    _signupConfirmPasswordController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      await authProvider.loadRegistrationRoles();

      if (!mounted ||
          authProvider.registrationRoles.isEmpty ||
          _selectedRoleName != null) {
        return;
      }

      setState(() {
        _selectedRoleName = authProvider.registrationRoles.first.name;
      });
    });
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _authMode = _authMode == AuthMode.login
          ? AuthMode.signup
          : AuthMode.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final availableRoles = authProvider.registrationRoles;
    final selectedRole = AuthFormActions.resolveSelectedRole(
      roles: availableRoles,
      selectedRoleName: _selectedRoleName,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2BB5BD), AppColors.pine, AppColors.forest],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative orbs
            const Positioned(
              top: -60,
              right: -50,
              child: DecorativeOrb(size: 180, color: Color(0x0FFFFFFF)),
            ),
            const Positioned(
              left: -40,
              bottom: 120,
              child: DecorativeOrb(size: 140, color: Color(0x0DFFFFFF)),
            ),
            const Positioned(
              right: -30,
              bottom: 200,
              child: DecorativeOrb(size: 110, color: Color(0x0AFFFFFF)),
            ),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Logo header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  // Hero section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
                    child: HeroContent(authMode: _authMode),
                  ),

                  const SizedBox(height: 16),

                  // White bottom sheet (scrollable form)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Scrollable form area
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Title
                                  Text(
                                    _authMode == AuthMode.login
                                        ? 'Login'
                                        : 'Sign up',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Toggle prompt
                                  AuthModePrompt(
                                    authMode: _authMode,
                                    onToggle: _toggleMode,
                                  ),

                                  // Error banner
                                  if (authProvider.errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    AuthErrorBanner(
                                      message: authProvider.errorMessage!,
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // Form
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 240),
                                    child: _authMode == AuthMode.login
                                        ? _buildLoginForm(authProvider)
                                        : _buildSignupForm(
                                            authProvider,
                                            availableRoles,
                                            selectedRole,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Fixed partner footer
                          const PartnerFooter(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider authProvider) {
    return KeyedSubtree(
      key: const ValueKey('login-form'),
      child: Form(
        key: _loginFormKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthLoginField(
                controller: _loginController,
                validator: AuthFormActions.validateLoginCredential,
                lightSurface: true,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                  AutofillHints.telephoneNumber,
                ],
              ),
              const SizedBox(height: 16),
              AuthPasswordField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                obscureText: !_showLoginPassword,
                onToggleVisibility: () {
                  setState(() => _showLoginPassword = !_showLoginPassword);
                },
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                lightSurface: true,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Password is required.' : null,
                onFieldSubmitted: (_) => AuthFormActions.submitLogin(
                  context: context,
                  formKey: _loginFormKey,
                  loginController: _loginController,
                  passwordController: _passwordController,
                ),
              ),
              const SizedBox(height: 12),
              RememberForgotRow(
                rememberMe: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Login',
                isLoading: authProvider.isBusy,
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                onPressed: () => AuthFormActions.submitLogin(
                  context: context,
                  formKey: _loginFormKey,
                  loginController: _loginController,
                  passwordController: _passwordController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm(
    AuthProvider authProvider,
    List<RegistrationRole> availableRoles,
    RegistrationRole? selectedRole,
  ) {
    return KeyedSubtree(
      key: const ValueKey('signup-form'),
      child: Form(
        key: _signupFormKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthRoleDropdown(
                roles: availableRoles,
                initialValue: selectedRole?.name ?? _selectedRoleName,
                isLoading: context
                    .read<AuthProvider>()
                    .isLoadingRegistrationRoles,
                onChanged: (v) => setState(() => _selectedRoleName = v),
                lightSurface: true,
              ),
              if (selectedRole != null) ...[
                const SizedBox(height: 12),
                AuthRoleDescription(
                  description: selectedRole.description,
                  lightSurface: true,
                ),
              ],
              const SizedBox(height: 16),
              AuthNameField(
                controller: _signupNameController,
                lightSurface: true,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Name is required.' : null,
              ),
              const SizedBox(height: 16),
              AuthEmailField(
                controller: _signupEmailController,
                validator: AuthFormActions.validateEmail,
                lightSurface: true,
                autofillHints: const [
                  AutofillHints.newUsername,
                  AutofillHints.email,
                ],
              ),
              const SizedBox(height: 16),
              AuthPasswordField(
                controller: _signupPasswordController,
                label: 'Password',
                hint: 'At least 6 characters',
                obscureText: !_showSignupPassword,
                onToggleVisibility: () {
                  setState(() => _showSignupPassword = !_showSignupPassword);
                },
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                lightSurface: true,
                validator: (v) {
                  final p = v ?? '';
                  if (p.isEmpty) return 'Password is required.';
                  if (p.length < 6) return 'Use at least 6 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AuthPasswordField(
                controller: _signupConfirmPasswordController,
                label: 'Confirm password',
                hint: 'Re-enter your password',
                prefixIcon: Icons.lock_person_outlined,
                obscureText: !_showConfirmPassword,
                onToggleVisibility: () {
                  setState(() => _showConfirmPassword = !_showConfirmPassword);
                },
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                lightSurface: true,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Please confirm your password.';
                  if (v != _signupPasswordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => AuthFormActions.submitSignUp(
                  context: context,
                  formKey: _signupFormKey,
                  selectedRoleName: selectedRole?.name,
                  nameController: _signupNameController,
                  emailController: _signupEmailController,
                  passwordController: _signupPasswordController,
                  passwordConfirmationController:
                      _signupConfirmPasswordController,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Create account',
                isLoading: authProvider.isBusy,
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                onPressed: () => AuthFormActions.submitSignUp(
                  context: context,
                  formKey: _signupFormKey,
                  selectedRoleName: selectedRole?.name,
                  nameController: _signupNameController,
                  emailController: _signupEmailController,
                  passwordController: _signupPasswordController,
                  passwordConfirmationController:
                      _signupConfirmPasswordController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
