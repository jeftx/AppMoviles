import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Avatar basado en el nombre de la cuenta.
///
/// La suma de los caracteres permite conservar el mismo color para una misma
/// persona, incluso después de cerrar y abrir la aplicación.
class ProfileAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const ProfileAvatar({
    required this.name,
    required this.radius,
    super.key,
  });

  static const _colors = <Color>[
    Color(0xFFE8DEF8),
    Color(0xFFF8DCE7),
    Color(0xFFD8ECDD),
    Color(0xFFDDEAF7),
    Color(0xFFF7E7C7),
  ];

  static String initialForName(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'U';

    return String.fromCharCode(trimmedName.runes.first).toUpperCase();
  }

  static Color colorForName(String name) {
    final value = name.trim().runes.fold<int>(
          0,
          (total, character) => total + character,
        );
    return _colors[value % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorForName(name),
      child: Text(
        initialForName(name),
        style: GoogleFonts.nunito(
          fontSize: radius * .78,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
