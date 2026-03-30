import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tanodmobile/frontend/modules/auth/screens/login_screen.dart';
import 'package:tanodmobile/frontend/modules/splash/screens/splash_screen.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/models/domain/registration_role.dart';
import 'package:tanodmobile/models/local/app_session.dart';
import 'package:tanodmobile/repository/contracts/auth_repository.dart';

void main() {
  testWidgets('Splash screen renders Tanod branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Tanod Mobile'), findsOneWidget);
    expect(find.text('Operations at a glance.'), findsOneWidget);
  });

  testWidgets('Login screen renders without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(authRepository: _FakeAuthRepository()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Login'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<List<RegistrationRole>> fetchRegistrationRoles() async {
    return RegistrationRole.fallbacks;
  }

  @override
  Future<AppSession?> restoreSession() async {
    return null;
  }

  @override
  Future<AppSession> refreshSession(AppSession session) async {
    return session;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<AppSession> signIn({required String login, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<AppSession> signUp({
    required String role,
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> registerFcmToken() async {}
}
