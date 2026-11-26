import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/categories/presentation/categories_page.dart';
import '../../features/foods/presentation/foods_page.dart';

import '../theme/app_colors.dart';
import 'construction_page.dart';

/// Abre el panel lateral sin reemplazar la pantalla que está detrás.
Future<void> showMoreMenu(
  BuildContext context, {
  required VoidCallback onProfile,
  bool isProfile = false,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Cerrar menú Más',
  barrierColor: Colors.black.withValues(alpha: .32),
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (dialogContext, animation, secondaryAnimation) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: (constraints.maxWidth * .82).clamp(0.0, 320.0),
        height: constraints.maxHeight,
        child: Material(
          color: AppColors.surface,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Más',
                          style: GoogleFonts.quicksand(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar menú',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      const _MoreItem(
                        icon: Icons.menu_book_outlined,
                        label: 'Menús personalizados',
                      ),
                      _MoreItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Categorías',
                        onTap: () {
                          final navigator = Navigator.of(dialogContext);
                          navigator.pop();
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CategoriesPage(),
                            ),
                          );
                        },
                      ),
                      _MoreItem(
                        icon: Icons.apple_outlined,
                        label: 'Alimentos',
                        onTap: () {
                          final navigator = Navigator.of(dialogContext);
                          navigator.pop();
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FoodsPage(),
                            ),
                          );
                        },
                      ),
                      const _MoreItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Dashboard',
                      ),
                      const _MoreItem(
                        icon: Icons.history_rounded,
                        label: 'Historial',
                      ),
                      const _MoreItem(
                        icon: Icons.track_changes_outlined,
                        label: 'Metas calóricas',
                      ),
                      _MoreItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Perfil',
                        selected: isProfile,
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          if (!isProfile) onProfile();
                        },
                      ),
                      const _MoreItem(
                        icon: Icons.settings_outlined,
                        label: 'Configuración',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
);

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? const Color(0xFFF9E5EC) : Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap:
            onTap ??
            () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(constructionRoute(label));
            },
        borderRadius: BorderRadius.circular(26),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 21, color: AppColors.textMain),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textMain,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
