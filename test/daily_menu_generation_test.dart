import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/ai/nutrition_ai_service.dart';

void main() {
  List<Map<String, dynamic>> foods() => [
    {
      'name': 'Tomate y aguacate, 100 g',
      'category': 'ensalada',
      'calories': 70,
    },
    {'name': 'Arepa, 1 unidad', 'category': 'carbohidrato', 'calories': 100},
    {'name': 'Huevo, 1 unidad', 'category': 'proteina', 'calories': 90},
    {'name': 'Jugo de naranja, 1 vaso', 'category': 'jugo', 'calories': 90},
  ];
  Map<String, dynamic> response() => {
    'meals': [
      {
        'type': 'Desayuno',
        'name': 'Arepa con huevo',
        'description': 'Arepa con huevo.',
        'foods': foods(),
      },
      {
        'type': 'Almuerzo',
        'name': 'Arroz con pollo',
        'description': 'Arroz y pollo.',
        'foods': foods(),
      },
      {
        'type': 'Snack',
        'name': 'Banano',
        'description': 'Banano.',
        'foods': foods(),
      },
      {
        'type': 'Cena',
        'name': 'Sopa de verduras',
        'description': 'Sopa.',
        'foods': foods(),
      },
    ],
  };

  test('acepta cuatro comidas distintas con calorías', () {
    final menu = NutritionAiService.parseDailyOutline(response());
    expect(menu.meals.length, 4);
    expect(menu.meals.first.calories, 350);
    expect(menu.meals.first.foods.length, 4);
    expect(menu.source, 'ai');
    expect(menu.meals.first.ingredients, isEmpty);
    expect(menu.meals.map((meal) => meal.id).toSet().length, 4);
  });

  test('rechaza categorías incompletas o tipos repetidos', () {
    final missing = response();
    ((missing['meals'] as List)[0]['foods'] as List).removeLast();
    expect(
      () => NutritionAiService.parseDailyOutline(missing),
      throwsFormatException,
    );
    final duplicate = response();
    (duplicate['meals'] as List)[1]['type'] = 'Desayuno';
    expect(
      () => NutritionAiService.parseDailyOutline(duplicate),
      throwsFormatException,
    );
  });

  test('rechaza categorías repetidas y calorías inválidas', () {
    final repeated = response();
    ((repeated['meals'] as List)[0]['foods'] as List)[1]['category'] =
        'ensalada';
    expect(
      () => NutritionAiService.parseDailyOutline(repeated),
      throwsFormatException,
    );
    final invalid = response();
    ((invalid['meals'] as List)[0]['foods'] as List)[0]['calories'] = 0;
    expect(
      () => NutritionAiService.parseDailyOutline(invalid),
      throwsFormatException,
    );
  });

  test('muestra el error real sin exponer direcciones ni claves', () {
    final message = NutritionAiService.menuMessageFor(
      Exception(
        'servicio no disponible en https://example.com/?key=secreto token=abc',
      ),
    );
    expect(message, contains('servicio no disponible'));
    expect(message, isNot(contains('secreto')));
    expect(message, isNot(contains('token=abc')));
  });
}
