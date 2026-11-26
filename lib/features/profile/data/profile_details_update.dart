import '../../../core/ai/nutrition_models.dart';
import '../../../core/nutrition/water_goal.dart';

/// Solo datos editables del perfil. Los menús y sus indicadores no se escriben.
class ProfileDetailsUpdate {
  const ProfileDetailsUpdate({
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.sex,
    required this.activityLevel,
    required this.country,
    required this.restrictions,
    required this.healthNotes,
    required this.goal,
  });

  final int age;
  final double heightCm;
  final double weightKg;
  final String sex;
  final String activityLevel;
  final String country;
  final List<String> restrictions;
  final String healthNotes;
  final String goal;

  Map<String, dynamic> toMap(UserNutritionProfile original) {
    final changesEnergy =
        !original.hasProfileDetails ||
        age != original.age ||
        heightCm != original.heightCm ||
        weightKg != original.weightKg ||
        sex != original.sex ||
        activityLevel != original.activityLevel ||
        goal != original.goal;
    final changesWater =
        !original.hasProfileDetails || weightKg != original.weightKg;
    final result = <String, dynamic>{
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'sex': sex,
      'activityLevel': activityLevel,
      'country': country,
      'restrictions': restrictions,
      'healthNotes': healthNotes,
      'goal': goal,
      'hasProfileDetails': true,
    };
    if (changesEnergy) {
      final bmr = switch (sex) {
        'Hombre' => 10 * weightKg + 6.25 * heightCm - 5 * age + 5,
        'Mujer' => 10 * weightKg + 6.25 * heightCm - 5 * age - 161,
        _ => 10 * weightKg + 6.25 * heightCm - 5 * age - 78,
      };
      final factor = switch (activityLevel) {
        'Sedentaria' => 1.2,
        'Ligera' => 1.375,
        'Moderada' => 1.55,
        'Alta' => 1.725,
        _ => 1.55,
      };
      final adjustment = switch (goal) {
        'Bajar de peso' => -350,
        'Ganar masa muscular' => 300,
        _ => 0,
      };
      result['dailyCalorieGoal'] = (bmr * factor + adjustment).round().clamp(
        1200,
        4000,
      );
    }
    if (changesWater) {
      result['dailyWaterGoalMl'] = dailyWaterGoalMl(weightKg);
    }
    return result;
  }
}
