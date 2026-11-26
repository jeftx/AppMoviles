import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/ai/nutrition_models.dart';

void main() {
  test('una propuesta diaria conserva sus campos al guardarse y leerse', () {
    const day = WeeklyMenuDay(
      day: 'Hoy',
      source: 'ai',
      meals: [
        MenuMeal(
          id: 'prueba-desayuno',
          type: 'Desayuno',
          name: 'Arepa con huevo',
          description: 'Arepa y huevo.',
          calories: 0,
          foods: [
            MenuFoodItem(
              name: 'Arepa, 1 unidad',
              category: FoodCategory.carbohidrato,
              calories: 100,
            ),
          ],
        ),
      ],
    );
    final restored = WeeklyMenuDay.fromJson(day.toJson());
    expect(restored.meals.single.id, 'prueba-desayuno');
    expect(restored.meals.single.name, 'Arepa con huevo');
    expect(restored.meals.single.ingredients, isEmpty);
    expect(restored.meals.single.steps, isEmpty);
    expect(restored.source, 'ai');
    expect(
      restored.meals.single.foods.single.category,
      FoodCategory.carbohidrato,
    );
  });

  test('una receta detallada conserva ingredientes, pasos y nutrientes', () {
    const meal = MenuMeal(
      id: 'prueba-desayuno',
      type: 'Desayuno',
      name: 'Arepa con huevo',
      description: 'Arepa y huevo.',
      calories: 300,
      proteinGrams: 15,
      ingredients: [MealIngredient(name: 'Huevo', amount: '1 unidad')],
      steps: ['Cocina el huevo.'],
      vitamins: [NutrientItem(name: 'Vitamina D', amount: '1 µg')],
      allergensAndPrecautions: 'Contiene huevo.',
    );
    final restored = MenuMeal.fromJson(meal.toJson());
    expect(restored.id, meal.id);
    expect(restored.calories, 300);
    expect(restored.proteinGrams, 15);
    expect(restored.ingredients.single.amount, '1 unidad');
    expect(restored.steps.single, 'Cocina el huevo.');
    expect(restored.vitamins.single.name, 'Vitamina D');
    expect(restored.allergensAndPrecautions, 'Contiene huevo.');
  });
}
