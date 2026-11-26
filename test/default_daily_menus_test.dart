import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/ai/default_daily_menus.dart';
import 'package:flutter_app/core/ai/nutrition_models.dart';

void main() {
  test('las tres alternativas guardan alimentos y categorías sin calorías inventadas', () {
    for (var i = 0; i < 3; i++) {
      final menu = DefaultDailyMenus.menuAt(i);
      final stored = WeeklyMenuDay.fromJson(menu.toJson());
      expect(stored.source, 'default');
      expect(stored.meals.map((m) => m.type), [
        'Desayuno',
        'Almuerzo',
        'Snack',
        'Cena',
      ]);
      for (final meal in stored.meals) {
        expect(meal.calories, 0);
        for (final food in meal.foods) {
          expect(food.name, isNotEmpty);
          expect(food.toJson().keys, containsAll(['name', 'category']));
          expect(food.toJson().containsKey('calories'), isFalse);
        }
      }
    }
    final breakfast = DefaultDailyMenus.menuAt(0).meals.first.foods;
    expect(breakfast.first.name, 'Huevos pericos');
    expect(breakfast.first.category, FoodCategory.proteina);
    final dinner = DefaultDailyMenus.menuAt(1).meals.last.foods;
    expect(
      dinner.any(
        (f) => f.name == 'Atún' && f.category == FoodCategory.proteina,
      ),
      isTrue,
    );
    expect(
      dinner.any(
        (f) =>
            f.name == 'Ensalada de atún con aguacate' &&
            f.category == FoodCategory.ensalada,
      ),
      isTrue,
    );
    expect(DefaultDailyMenus.choose(random: Random(7)).meals, isNotEmpty);
  });

  test('no usa alternativas sin verificar restricciones o indicaciones', () {
    UserNutritionProfile profile(List<String> restrictions, String notes) =>
        UserNutritionProfile.fromMap({
          'age': 30,
          'restrictions': restrictions,
          'healthNotes': notes,
        });
    expect(DefaultDailyMenus.canUse(profile(['Ninguna'], '')), isTrue);
    expect(DefaultDailyMenus.canUse(profile(['Sin lactosa'], '')), isFalse);
    expect(DefaultDailyMenus.canUse(profile([], 'Diabetes')), isFalse);
    expect(
      DefaultDailyMenus.canUse(UserNutritionProfile.fromMap({'age': 15})),
      isFalse,
    );
  });

  test('recupera desayuno original si el resto identifica el menú', () {
    final original = DefaultDailyMenus.menuAt(0);
    final changed = WeeklyMenuDay(
      day: 'Hoy',
      source: 'default',
      meals: [
        const MenuMeal(
          type: 'Desayuno',
          name: 'Arroz cocido',
          description: '',
          calories: 0,
        ),
        ...original.meals.skip(1),
      ],
    );
    expect(
      DefaultDailyMenus.originalBreakfast(changed)?.name,
      original.meals.first.name,
    );
    expect(
      DefaultDailyMenus.originalBreakfast(
        const WeeklyMenuDay(day: 'Hoy', source: 'default', meals: []),
      ),
      isNull,
    );
  });
}
