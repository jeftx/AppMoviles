import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/ai/nutrition_models.dart';

void main() {
  UserNutritionProfile profileWithLegacyMenu(bool active) =>
      UserNutritionProfile.fromMap({
        'name': 'Ana',
        'hasWeeklyMenu': active,
        'weeklyMenu': {
          'days': [
            {
              'day': 'Lunes',
              'meals': [
                {
                  'id': '1',
                  'type': 'Desayuno',
                  'name': 'Arepa',
                  'calories': 200,
                },
              ],
            },
          ],
        },
      });

  test('oculta el menú anterior marcado como inactivo sin borrarlo', () {
    final profile = profileWithLegacyMenu(false);

    expect(profile.activeLegacyMenuFor(DateTime(2026, 11, 23)), isNull);
    expect(profile.weeklyMenu!.days.single.meals.single.name, 'Arepa');
  });

  test('conserva visible un menú anterior marcado como activo', () {
    final profile = profileWithLegacyMenu(true);

    expect(
      profile.activeLegacyMenuFor(DateTime(2026, 11, 23))!.meals.single.name,
      'Arepa',
    );
  });

  test('no muestra un menú anterior cuando no hay datos guardados', () {
    final profile = UserNutritionProfile.fromMap({'name': 'Ana'});

    expect(profile.activeLegacyMenuFor(DateTime(2026, 11, 23)), isNull);
  });
}
