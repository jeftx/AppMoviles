import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/ai/nutrition_models.dart';
import 'package:flutter_app/features/foods/data/foods_repository.dart';

void main() {
  test('guarda el título y categoría sin inventar calorías', () {
    const food = UserFood(title: '  Papaya  ', category: FoodCategory.fruta);
    final data = food.toMap();
    expect(data['title'], 'Papaya');
    expect(data['category'], 'fruta');
    expect(data.containsKey('calories'), isFalse);
    expect(UserFood.fromMap(data).calories, isNull);
  });

  test('conserva las calorías opcionales incluida una cantidad de cero', () {
    const food = UserFood(
      title: 'Agua',
      category: FoodCategory.jugo,
      calories: 0,
    );
    final restored = UserFood.fromMap(food.toMap());
    expect(restored.calories, 0);
    expect(restored.category, FoodCategory.jugo);
  });
}
