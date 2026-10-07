import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [AppTheme.globalShadow],
          ),
          child: const Center(
            child: Icon(Icons.eco, color: AppColors.primaryDark, size: 36),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NutriMenu AI',
          style: GoogleFonts.quicksand(
            fontSize: 30,
            height: 36 / 30,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: Text(
            'Genera menús semanales adaptados a tus objetivos con IA',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textMain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '🥗 🍓 🥑',
          style: TextStyle(fontSize: 36, height: 40 / 36),
        ),
      ],
    );
  }
}