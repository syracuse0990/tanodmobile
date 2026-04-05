import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());

  bool _codeSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _otpCode =>
      _codeControllers.map((c) => c.text).join();

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else {
        if (mounted) setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendCode() async {
    setState(() => _isSending = true);

    try {
      await context.read<AuthProvider>().sendPhoneVerificationCode();
      if (mounted) {
        setState(() => _codeSent = true);
        _startCooldown();
        AppToast.success('Verification code sent');
        _codeFocusNodes[0].requestFocus();
      }
    } on AppException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (e) {
      if (mounted) AppToast.error('Failed to send verification code');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verify() async {
    final code = _otpCode;
    if (code.length != 6) {
      AppToast.error('Please enter the 6-digit code');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await context.read<AuthProvider>().verifyPhone(code: code);
      if (mounted) {
        AppToast.success('Phone number verified!');
        Navigator.pop(context);
      }
    } on AppException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (e) {
      if (mounted) AppToast.error('Verification failed');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _codeFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _codeFocusNodes[index - 1].requestFocus();
    }
    // Auto-submit when all 6 digits entered
    if (_otpCode.length == 6) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final phone = user?.phone;
    final isVerified = user?.phoneVerifiedAt != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Phone Verification',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          children: [
            // Status icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isVerified
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isVerified
                    ? Icons.verified_rounded
                    : Icons.phone_android_rounded,
                size: 36,
                color: isVerified ? AppColors.success : AppColors.gold,
              ),
            ),
            const SizedBox(height: 20),

            if (isVerified) ...[
              const Text(
                'Phone Verified',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phone ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pine,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your phone number has been verified successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedInk.withValues(alpha: 0.7),
                ),
              ),
            ] else if (phone == null || phone.isEmpty) ...[
              const Text(
                'No Phone Number',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please add a phone number in your profile first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedInk.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forest,
                    side: const BorderSide(color: AppColors.forest),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Go to Edit Profile'),
                ),
              ),
            ] else ...[
              // Unverified with phone
              Text(
                _codeSent ? 'Enter Verification Code' : 'Verify Your Number',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'We sent a 6-digit code to'
                    : 'We will send a verification code to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedInk.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pine,
                ),
              ),

              if (!_codeSent) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.forest.withValues(alpha: 0.5),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Verification Code'),
                  ),
                ),
              ],

              if (_codeSent) ...[
                const SizedBox(height: 32),

                // OTP input
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 48,
                        height: 56,
                        margin: EdgeInsets.only(
                          right: index < 5 ? 8 : 0,
                          left: index == 3 ? 8 : 0,
                        ),
                      child: TextFormField(
                        controller: _codeControllers[index],
                        focusNode: _codeFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        onChanged: (v) => _onCodeChanged(index, v),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  AppColors.mutedInk.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  AppColors.mutedInk.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.forest,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                ),

                const SizedBox(height: 28),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.forest.withValues(alpha: 0.5),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ),

                const SizedBox(height: 20),

                // Resend
                TextButton(
                  onPressed:
                      _cooldown > 0 || _isSending ? null : _sendCode,
                  child: Text(
                    _cooldown > 0
                        ? 'Resend code in ${_cooldown}s'
                        : 'Resend Code',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _cooldown > 0
                          ? AppColors.mutedInk.withValues(alpha: 0.4)
                          : AppColors.forest,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
