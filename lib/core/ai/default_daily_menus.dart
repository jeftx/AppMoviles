import 'dart:math';

import 'nutrition_models.dart';

class DefaultDailyMenus {
  static bool canUse(UserNutritionProfile profile) =>
      profile.age >= 18 &&
      profile.healthNotes.trim().isEmpty &&
      profile.restrictions.every(
        (r) => r.trim().isEmpty || r.trim().toLowerCase() == 'ninguna',
      );

  static MenuFoodItem _food(String name, FoodCategory category) =>
      MenuFoodItem(name: name, category: category, calories: 0);

  static WeeklyMenuDay choose({Random? random}) =>
      menuAt((random ?? Random()).nextInt(3));

  /// Reconoce una alternativa original solo si al menos dos comidas coinciden.
  static MenuMeal? originalBreakfast(WeeklyMenuDay current) {
    if (current.source != 'default') return null;
    for (var index = 0; index < 3; index++) {
      final candidate = menuAt(index);
      final matches = current.meals
          .where(
            (meal) =>
                meal.type.toLowerCase() != 'desayuno' &&
                candidate.meals.any(
                  (original) =>
                      original.id == meal.id && original.name == meal.name,
                ),
          )
          .length;
      if (matches >= 2) return candidate.meals.first;
    }
    return null;
  }

  static WeeklyMenuDay menuAt(int index) {
    if (index < 0 || index >= 3) throw RangeError.range(index, 0, 2);
    const p = FoodCategory.proteina,
        c = FoodCategory.carbohidrato,
        e = FoodCategory.ensalada,
        v = FoodCategory.verdura,
        s = FoodCategory.sopa,
        f = FoodCategory.fruta,
        n = FoodCategory.snack,
        b = FoodCategory.jugo;
    final menus = <List<List<MenuFoodItem>>>[
      [
        [
          _food('Huevos pericos', p),
          _food('Arepa santandereana', c),
          _food('Papaya', f),
          _food('Chocolate caliente', b),
        ],
        [
          _food('Sopa de lentejas', s),
          _food('Pechuga de pollo a la plancha', p),
          _food('Arroz blanco', c),
          _food('Ensalada de cebolla, tomate y aguacate', e),
          _food('Jugo de mora en agua', b),
        ],
        [
          _food('Bocadillo veleño con queso', n),
          _food('Aromática de hierbabuena', b),
        ],
        [
          _food('Crema de ahuyama', s),
          _food('Queso campesino', p),
          _food('Arepa santandereana', c),
          _food('Espinaca salteada', v),
        ],
      ],
      [
        [
          _food('Queso campesino', p),
          _food('Almojábana', c),
          _food('Mango', f),
          _food('Agua de panela con limón', b),
        ],
        [
          _food('Caldo de costilla', s),
          _food('Carne de res a la plancha', p),
          _food('Papa criolla', c),
          _food('Ensalada de remolacha', e),
          _food('Habichuelas con zanahoria al vapor', v),
          _food('Jugo de lulo en leche', b),
        ],
        [_food('Maní salado', n), _food('Mandarina', f)],
        [
          _food('Ensalada de atún con aguacate', e),
          _food('Atún', p),
          _food('Yuca cocida', c),
          _food('Aromática de hierbabuena', b),
        ],
      ],
      [
        [
          _food('Frijol y arroz', c),
          _food('Huevo', p),
          _food('Banano', f),
          _food('Café con leche', b),
        ],
        [
          _food('Ajiaco santafereño', s),
          _food('Mojarra frita', p),
          _food('Patacones', c),
          _food('Ensalada de aguacate y mango', e),
          _food('Limonada de coco', b),
        ],
        [_food('Oblea con arequipe', n), _food('Tinto', b)],
        [
          _food('Huevos pericos', p),
          _food('Arepa asada', c),
          _food('Queso campesino', p),
          _food('Brócoli al vapor', v),
          _food('Piña', f),
        ],
      ],
    ];
    const types = ['Desayuno', 'Almuerzo', 'Snack', 'Cena'];
    const names = [
      [
        'Huevos pericos con arepa',
        'Pollo a la plancha',
        'Bocadillo veleño con queso',
        'Crema de ahuyama con queso y arepa',
      ],
      [
        'Almojábana con queso',
        'Carne a la plancha con papa criolla',
        'Maní con mandarina',
        'Ensalada de atún con yuca',
      ],
      [
        'Calentado de frijol con huevo',
        'Mojarra frita con patacones',
        'Oblea con arequipe',
        'Huevos pericos con arepa y queso',
      ],
    ];
    return WeeklyMenuDay(
      day: 'Hoy',
      source: 'default',
      meals: [
        for (var i = 0; i < 4; i++)
          MenuMeal(
            id: 'predeterminado-$index-$i',
            type: types[i],
            name: names[index][i],
            description: menus[index][i].map((food) => food.name).join(', '),
            calories: 0,
            foods: menus[index][i],
          ),
      ],
    );
  }
}
