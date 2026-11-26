import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../home_screen.dart';
import '../../../onboarding/presentation/pages/onboarding_page.dart';
import '../../../profile/data/nutrition_profile_repository.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) return const LoginPage();

        final user = snapshot.data!;
        return StreamBuilder(
          key: ValueKey('auth-profile-${user.uid}'),
          stream: NutritionProfileRepository().watch(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (profileSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar tu perfil. Revisa tu conexión y vuelve a abrir la aplicación.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            return profileSnapshot.hasData
                ? const HomeScreen()
                : const OnboardingPage();
          },
        );
      },
    );
  }
}
