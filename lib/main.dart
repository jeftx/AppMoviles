// lib/main.dart
import 'package:flutter/material.dart';
// Asegúrate de ajustar la ruta de importación según dónde guardaste tu LoginPage
import 'features/auth/presentation/pages/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriMenu AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Aquí puedes enlazar tu AppTheme global si lo deseas
      ),
      home: const LoginPage(),
    );
  }
}