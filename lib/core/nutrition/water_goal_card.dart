import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'water_goal.dart';

class WaterGoalCard extends StatelessWidget {
  const WaterGoalCard({super.key, required this.weightKg});
  final double? weightKg;

  @override
  Widget build(BuildContext context) {
    final glasses = dailyWaterGlasses(weightKg ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppTheme.globalShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.water_drop_outlined,
            color: Color(0xFF2C4A3E),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agua',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  glasses == 0
                      ? 'Agrega tu peso para calcular la meta'
                      : 'Meta diaria: $glasses vasos · ${glasses * 250} ml',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (glasses > 0) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    label: 'Meta de $glasses vasos de 250 mililitros',
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: List.generate(
                        glasses,
                        (index) => Container(
                          key: ValueKey('water-glass-$index'),
                          width: 11,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8E1D0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
