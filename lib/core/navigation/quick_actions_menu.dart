import 'dart:ui';

import 'package:flutter/material.dart';

import '../../features/food_scan/presentation/pages/food_scan_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/foods/presentation/foods_page.dart';
import '../theme/app_colors.dart';
import 'construction_page.dart';

/// Botón central y menú de acciones compartido por las barras inferiores.
class QuickActionsButton extends StatelessWidget {
  const QuickActionsButton({super.key});

  @override
  Widget build(BuildContext context) => _CircleButton(
    icon: Icons.add,
    label: 'Abrir acciones rápidas',
    onTap: () => _openQuickActions(context),
  );
}

Future<void> _openQuickActions(BuildContext context) async {
  final selected = await showGeneralDialog<_QuickAction>(
    context: context,
    barrierLabel: 'Cerrar acciones rápidas',
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        const _QuickActionsOverlay(),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  if (!context.mounted || selected == null) return;
  if (selected == _QuickAction.food) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FoodsPage()));
    return;
  }
  if (selected == _QuickAction.category) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const CategoriesPage()));
    return;
  }
  if (selected == _QuickAction.scan) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FoodScanPage()));
    return;
  }
  openConstructionPage(context, selected.label);
}

enum _QuickAction {
  customMenu('Añadir menú personalizado', Icons.restaurant_outlined),
  category('Categorías', Icons.sell_outlined),
  food('Añadir alimento', Icons.apple_outlined),
  scan('Escanear comida', Icons.document_scanner_outlined),
  randomMenu('Generar menú aleatorio', Icons.shuffle_rounded);

  const _QuickAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _QuickActionsOverlay extends StatelessWidget {
  const _QuickActionsOverlay();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              bottom: bottom + 72,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Container(
                      color: Colors.black.withValues(alpha: .12),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: bottom + 92,
              left: 24,
              right: 24,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 410,
                    maxHeight: (constraints.maxHeight - bottom - 120).clamp(
                      0,
                      420,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in _QuickAction.values) ...[
                          _ActionTile(action: action),
                          if (action != _QuickAction.values.last)
                            const SizedBox(height: 9),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: bottom + 8,
              left: 0,
              right: 0,
              child: Center(
                child: _CircleButton(
                  icon: Icons.close,
                  label: 'Cerrar acciones rápidas',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.pop(context, action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFCFE3D4),
              child: Icon(
                action.icon,
                color: const Color(0xFF344B3C),
                size: 20,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                action.label,
                style: const TextStyle(fontSize: 14, color: AppColors.textMain),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: AppColors.primaryDark, size: 29),
        ),
      ),
    ),
  );
}
