import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/ai/nutrition_models.dart';
import 'package:flutter_app/features/profile/data/profile_details_update.dart';

void main() {
  const profile = UserNutritionProfile(
    name: 'Ana',
    age: 28,
    sex: 'Mujer',
    weightKg: 68,
    heightCm: 172,
    activityLevel: 'Moderada',
    country: 'Colombia',
    restrictions: [],
    healthNotes: '',
    goal: 'Mantener peso',
    dailyCalorieGoal: 2000,
    dailyWaterGoalMl: 2200,
    usesAiMenu: true,
    hasProfileDetails: true,
    hasWeeklyMenu: true,
  );

  test('editar restricciones nunca incluye los menús ni altera las metas', () {
    const update = ProfileDetailsUpdate(
      age: 28,
      heightCm: 172,
      weightKg: 68,
      sex: 'Mujer',
      activityLevel: 'Moderada',
      country: 'Colombia',
      restrictions: ['Sin lactosa'],
      healthNotes: '',
      goal: 'Mantener peso',
    );
    final fields = update.toMap(profile);
    expect(fields['restrictions'], ['Sin lactosa']);
    expect(fields.containsKey('weeklyMenu'), isFalse);
    expect(fields.containsKey('hasWeeklyMenu'), isFalse);
    expect(fields.containsKey('dailyMenus'), isFalse);
    expect(fields.containsKey('dailyCalorieGoal'), isFalse);
    expect(fields.containsKey('dailyWaterGoalMl'), isFalse);
  });

  test('cambiar el peso actualiza metas sin escribir menús', () {
    const update = ProfileDetailsUpdate(
      age: 28,
      heightCm: 172,
      weightKg: 70,
      sex: 'Mujer',
      activityLevel: 'Moderada',
      country: 'Colombia',
      restrictions: [],
      healthNotes: '',
      goal: 'Mantener peso',
    );
    final fields = update.toMap(profile);
    expect(fields['weightKg'], 70);
    expect(fields['dailyWaterGoalMl'], 2500);
    expect(fields['dailyCalorieGoal'], isA<int>());
    expect(fields.containsKey('weeklyMenu'), isFalse);
    expect(fields.containsKey('hasWeeklyMenu'), isFalse);
  });
}
