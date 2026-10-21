import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'G',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
        label: Text(
          isLoading ? 'Conectando con Google...' : 'Continuar con Google',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
      ),
    );
  }
}
