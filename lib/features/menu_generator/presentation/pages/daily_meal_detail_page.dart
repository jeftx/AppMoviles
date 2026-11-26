import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/ai/nutrition_ai_service.dart';
import '../../../../core/ai/nutrition_models.dart';
import '../../../profile/data/nutrition_profile_repository.dart';
import 'meal_detail_page.dart';

class DailyMealDetailPage extends StatefulWidget {
  final String userId;
  final String date;
  final UserNutritionProfile profile;
  final MenuMeal meal;
  final String imagePath;

  const DailyMealDetailPage({
    super.key,
    required this.userId,
    required this.date,
    required this.profile,
    required this.meal,
    required this.imagePath,
  });

  @override
  State<DailyMealDetailPage> createState() => _DailyMealDetailPageState();
}

class _DailyMealDetailPageState extends State<DailyMealDetailPage> {
  late MenuMeal _meal;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _meal = widget.meal;
    if (_meal.ingredients.isEmpty || _meal.steps.isEmpty) _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await NutritionAiService.generateMealDetails(
        widget.profile,
        widget.meal,
      );
      if (FirebaseAuth.instance.currentUser?.uid != widget.userId) {
        throw StateError('La sesión ha cambiado.');
      }
      await NutritionProfileRepository().saveDailyMealDetails(
        widget.userId,
        widget.date,
        widget.meal,
        detail,
      );
      if (mounted) setState(() => _meal = detail);
    } catch (error) {
      if (mounted) {
        setState(() => _error = NutritionAiService.menuMessageFor(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading &&
        _error == null &&
        _meal.ingredients.isNotEmpty &&
        _meal.steps.isNotEmpty) {
      return MealDetailPage(
        meal: _meal,
        imagePath: widget.imagePath,
        onDelete: () => NutritionProfileRepository().removeDailyMeal(
          widget.userId,
          widget.date,
          _meal,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.meal.type)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Preparando la receta de ${widget.meal.name}...'),
              ] else ...[
                Text(
                  _error ?? 'No se pudieron generar los detalles.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _generate,
                  child: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
