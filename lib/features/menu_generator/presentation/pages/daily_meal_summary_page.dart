import 'package:flutter/material.dart';

import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/nutrition_profile_repository.dart';

class DailyMealSummaryPage extends StatelessWidget {
  const DailyMealSummaryPage({
    super.key,
    required this.userId,
    required this.date,
    required this.meal,
    required this.imagePath,
  });

  final String userId;
  final String date;
  final MenuMeal meal;
  final String imagePath;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta comida?'),
        content: Text('Se eliminará ${meal.name} del menú de hoy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await NutritionProfileRepository().removeDailyMeal(userId, date, meal);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la comida. Inténtalo de nuevo.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(meal.type),
      backgroundColor: AppColors.background,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              meal.type.toUpperCase(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 5),
            Text(
              meal.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(meal.description),
            if (meal.foods.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Alimentos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              ...meal.foods.map(
                (food) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(food.name),
                  subtitle: Text(food.category.label),
                  trailing: food.calories > 0
                      ? Text('${food.calories} kcal')
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              meal.calories > 0 ? '${meal.calories} kcal aproximadas' : '---',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            const Text(
              'Los detalles de ingredientes y preparación estarán disponibles próximamente.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar comida'),
            ),
          ],
        ),
      ),
    ),
  );
}
