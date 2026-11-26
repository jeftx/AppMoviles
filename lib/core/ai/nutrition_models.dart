import 'dart:convert';

class UserNutritionProfile {
  final String name;
  final int age;
  final String sex;
  final double weightKg;
  final double heightCm;
  final String activityLevel;
  final String country;
  final List<String> restrictions;
  final String healthNotes;
  final String goal;
  final int dailyCalorieGoal;
  final int dailyWaterGoalMl;
  final bool usesAiMenu;
  final bool hasProfileDetails;
  final bool hasWeeklyMenu;
  final WeeklyMenu? weeklyMenu;

  const UserNutritionProfile({
    required this.name,
    required this.age,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.activityLevel,
    this.country = '',
    required this.restrictions,
    required this.healthNotes,
    required this.goal,
    required this.dailyCalorieGoal,
    required this.dailyWaterGoalMl,
    required this.usesAiMenu,
    this.hasProfileDetails = false,
    this.hasWeeklyMenu = false,
    this.weeklyMenu,
  });

  // Estos valores reflejan los datos que la pantalla de perfil muestra hoy.
  // Cuando el perfil sea editable, se reemplazarán por los datos guardados.
  static const demo = UserNutritionProfile(
    name: 'Usuario',
    age: 28,
    sex: 'Prefiero no decirlo',
    weightKg: 68,
    heightCm: 172,
    activityLevel: 'Moderada',
    country: '',
    restrictions: ['Sin lactosa'],
    healthNotes: '',
    goal: 'Mantener peso',
    dailyCalorieGoal: 1900,
    dailyWaterGoalMl: 2400,
    usesAiMenu: true,
    hasProfileDetails: false,
    hasWeeklyMenu: false,
  );

  Map<String, dynamic> toAiProfile() => {
    'edad_anios': age,
    'sexo': sex,
    'peso_kg': weightKg,
    'estatura_cm': heightCm,
    'nivel_actividad': activityLevel,
    'pais': country,
    'restricciones': restrictions,
    'indicaciones_salud': healthNotes,
    'objetivo': goal,
    'meta_calorica_diaria_kcal': dailyCalorieGoal,
  };

  String get promptSummary => jsonEncode(toAiProfile());

  /// Menús heredados solo visibles si la cuenta aún los marca como activos.
  WeeklyMenuDay? activeLegacyMenuFor(DateTime date) {
    if (!hasWeeklyMenu) return null;
    final days = weeklyMenu?.days;
    if (days == null || days.isEmpty) return null;
    return days[(date.weekday - 1) % days.length];
  }

  factory UserNutritionProfile.fromMap(Map<String, dynamic> map) {
    final restrictions = (map['restrictions'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final weeklyMap = _asStringMap(map['weeklyMenu']);
    return UserNutritionProfile(
      name: map['name'] as String? ?? 'Usuario',
      age: _asInt(map['age']),
      sex: map['sex'] as String? ?? 'Prefiero no decirlo',
      weightKg: _asDouble(map['weightKg']),
      heightCm: _asDouble(map['heightCm']),
      activityLevel: map['activityLevel'] as String? ?? 'Moderada',
      country: map['country'] as String? ?? '',
      restrictions: restrictions,
      healthNotes: map['healthNotes'] as String? ?? '',
      goal: map['goal'] as String? ?? '',
      dailyCalorieGoal: _asInt(map['dailyCalorieGoal']),
      dailyWaterGoalMl: _asInt(map['dailyWaterGoalMl']),
      usesAiMenu: map['usesAiMenu'] as bool? ?? true,
      hasProfileDetails: map['hasProfileDetails'] as bool? ?? false,
      hasWeeklyMenu: map['hasWeeklyMenu'] as bool? ?? false,
      weeklyMenu: weeklyMap == null ? null : WeeklyMenu.fromJson(weeklyMap),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'age': age,
    'sex': sex,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'activityLevel': activityLevel,
    'country': country,
    'restrictions': restrictions,
    'healthNotes': healthNotes,
    'goal': goal,
    'dailyCalorieGoal': dailyCalorieGoal,
    'dailyWaterGoalMl': dailyWaterGoalMl,
    'usesAiMenu': usesAiMenu,
    'hasProfileDetails': hasProfileDetails,
    'hasWeeklyMenu': hasWeeklyMenu,
    if (weeklyMenu != null) 'weeklyMenu': weeklyMenu!.toJson(),
    'onboardingCompleted': true,
  };
}

class FoodItem {
  final String name;
  final int calories;
  final double portionGrams;
  final String notes;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.portionGrams,
    required this.notes,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    name: json['name'] as String? ?? 'Alimento no identificado',
    calories: _asInt(json['calories']),
    portionGrams: _asDouble(json['portionGrams']),
    notes: json['notes'] as String? ?? '',
  );
}

class FoodAnalysis {
  final List<FoodItem> foods;
  final int totalCalories;
  final String summary;
  final String confidenceNote;

  const FoodAnalysis({
    required this.foods,
    required this.totalCalories,
    required this.summary,
    required this.confidenceNote,
  });

  factory FoodAnalysis.fromJson(Map<String, dynamic> json) {
    final foods = (json['foods'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FoodItem.fromJson)
        .toList();
    return FoodAnalysis(
      foods: foods,
      totalCalories: _asInt(json['totalCalories']),
      summary: json['summary'] as String? ?? '',
      confidenceNote:
          json['confidenceNote'] as String? ??
          'Estimación generada a partir de la imagen.',
    );
  }
}

class MealIngredient {
  final String name;
  final String amount;

  const MealIngredient({required this.name, required this.amount});

  factory MealIngredient.fromJson(Map<String, dynamic> json) => MealIngredient(
    name: json['name'] as String? ?? 'Ingrediente',
    amount: json['amount'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

class NutrientItem {
  final String name;
  final String amount;

  const NutrientItem({required this.name, required this.amount});

  factory NutrientItem.fromJson(Map<String, dynamic> json) => NutrientItem(
    name: json['name'] as String? ?? 'Nutriente',
    amount: json['amount'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

/// Categorías compartidas por menús generados y futuras creaciones manuales.
enum FoodCategory {
  ensalada,
  carbohidrato,
  proteina,
  jugo,
  sopa,
  fruta,
  verdura,
  snack,
  guiso,
  otro;

  String get label => switch (this) {
    FoodCategory.proteina => 'Proteína',
    FoodCategory.carbohidrato => 'Carbohidrato',
    FoodCategory.ensalada => 'Ensaladas',
    FoodCategory.verdura => 'Vegetales',
    FoodCategory.sopa => 'Sopa',
    FoodCategory.fruta => 'Fruta',
    FoodCategory.snack => 'Snacks',
    FoodCategory.jugo => 'Jugo y bebidas',
    FoodCategory.guiso => 'Guiso',
    FoodCategory.otro => 'Otro',
  };

  static FoodCategory? parse(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('í', 'i');
    for (final category in values) {
      if (category.name == normalized) return category;
    }
    return null;
  }
}

class MenuFoodItem {
  final String name;
  final FoodCategory category;
  final int calories;
  const MenuFoodItem({
    required this.name,
    required this.category,
    required this.calories,
  });

  factory MenuFoodItem.fromJson(Map<String, dynamic> json) => MenuFoodItem(
    name: json['name'] as String? ?? '',
    category:
        FoodCategory.parse(json['category'] as String? ?? '') ??
        FoodCategory.otro,
    calories: _asInt(json['calories']),
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category.name,
    if (calories > 0) 'calories': calories,
  };
}

class MenuMeal {
  final String id;
  final String type;
  final String name;
  final String description;
  final int calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;
  final String serving;
  final int prepMinutes;
  final List<MealIngredient> ingredients;
  final List<String> steps;
  final List<NutrientItem> vitamins;
  final List<NutrientItem> minerals;
  final String nutritionNotes;
  final String allergensAndPrecautions;
  final List<MenuFoodItem> foods;

  const MenuMeal({
    required this.type,
    required this.name,
    required this.description,
    required this.calories,
    this.id = '',
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams = 0,
    this.serving = '',
    this.prepMinutes = 0,
    this.ingredients = const [],
    this.steps = const [],
    this.vitamins = const [],
    this.minerals = const [],
    this.nutritionNotes = '',
    this.allergensAndPrecautions = '',
    this.foods = const [],
  });

  factory MenuMeal.fromJson(Map<String, dynamic> json) => MenuMeal(
    id: json['id'] as String? ?? '',
    type: json['type'] as String? ?? 'Comida',
    name: json['name'] as String? ?? 'Propuesta saludable',
    description: json['description'] as String? ?? '',
    calories: _asInt(json['calories']),
    proteinGrams: _asDouble(json['proteinGrams']),
    carbsGrams: _asDouble(json['carbsGrams']),
    fatGrams: _asDouble(json['fatGrams']),
    fiberGrams: _asDouble(json['fiberGrams']),
    serving: json['serving'] as String? ?? '',
    prepMinutes: _asInt(json['prepMinutes']),
    ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .map(MealIngredient.fromJson)
        .toList(),
    steps: (json['steps'] as List<dynamic>? ?? const [])
        .map((step) => step.toString())
        .where((step) => step.trim().isNotEmpty)
        .toList(),
    vitamins: (json['vitamins'] as List<dynamic>? ?? const [])
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .map(NutrientItem.fromJson)
        .toList(),
    minerals: (json['minerals'] as List<dynamic>? ?? const [])
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .map(NutrientItem.fromJson)
        .toList(),
    nutritionNotes: json['nutritionNotes'] as String? ?? '',
    allergensAndPrecautions: json['allergensAndPrecautions'] as String? ?? '',
    foods: (json['foods'] as List<dynamic>? ?? const [])
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .map(MenuFoodItem.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'description': description,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'fiberGrams': fiberGrams,
    'serving': serving,
    'prepMinutes': prepMinutes,
    'ingredients': ingredients
        .map((ingredient) => ingredient.toJson())
        .toList(),
    'steps': steps,
    'vitamins': vitamins.map((nutrient) => nutrient.toJson()).toList(),
    'minerals': minerals.map((nutrient) => nutrient.toJson()).toList(),
    'nutritionNotes': nutritionNotes,
    'allergensAndPrecautions': allergensAndPrecautions,
    'foods': foods.map((food) => food.toJson()).toList(),
  };
}

class GeneratedMenu {
  final String title;
  final int dailyCalories;
  final String rationale;
  final List<MenuMeal> meals;

  const GeneratedMenu({
    required this.title,
    required this.dailyCalories,
    required this.rationale,
    required this.meals,
  });

  factory GeneratedMenu.fromJson(Map<String, dynamic> json) => GeneratedMenu(
    title: json['title'] as String? ?? 'Menú saludable',
    dailyCalories: _asInt(json['dailyCalories']),
    rationale: json['rationale'] as String? ?? '',
    meals: (json['meals'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MenuMeal.fromJson)
        .toList(),
  );
}

class WeeklyMenuDay {
  final String day;
  final List<MenuMeal> meals;
  final String source;

  const WeeklyMenuDay({
    required this.day,
    required this.meals,
    this.source = 'unknown',
  });

  factory WeeklyMenuDay.fromJson(Map<String, dynamic> json) => WeeklyMenuDay(
    day: json['day'] as String? ?? 'Día',
    source: json['source'] as String? ?? 'unknown',
    meals: (json['meals'] as List<dynamic>? ?? const [])
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .map(MenuMeal.fromJson)
        .toList(),
  );

  int get totalCalories => meals.fold(0, (sum, meal) => sum + meal.calories);
  double get totalProtein =>
      meals.fold(0, (sum, meal) => sum + meal.proteinGrams);
  double get totalCarbs => meals.fold(0, (sum, meal) => sum + meal.carbsGrams);
  double get totalFat => meals.fold(0, (sum, meal) => sum + meal.fatGrams);

  Map<String, dynamic> toJson() => {
    'day': day,
    'source': source,
    'meals': meals.map((meal) => meal.toJson()).toList(),
  };
}

class WeeklyMenu {
  final int dailyCalories;
  final String source;
  final List<WeeklyMenuDay> days;

  const WeeklyMenu({
    required this.dailyCalories,
    required this.source,
    required this.days,
  });

  factory WeeklyMenu.fromJson(Map<String, dynamic> json) => WeeklyMenu(
    dailyCalories: _asInt(json['dailyCalories']),
    source: json['source'] as String? ?? 'manual',
    days: (json['days'] as List<dynamic>? ?? const [])
        .map(_asStringMap)
        .whereType<Map<String, dynamic>>()
        .map(WeeklyMenuDay.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'dailyCalories': dailyCalories,
    'source': source,
    'days': days.map((day) => day.toJson()).toList(),
  };

  static WeeklyMenu fallback(UserNutritionProfile profile) {
    final calories = profile.dailyCalorieGoal;
    const dayNames = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return WeeklyMenu(
      dailyCalories: calories,
      source: 'manual',
      days: dayNames
          .map(
            (day) => WeeklyMenuDay(
              day: day,
              meals: [
                MenuMeal(
                  id: '${day.toLowerCase()}-desayuno',
                  type: 'Desayuno',
                  name: 'Avena con fresas, arándanos y chía',
                  description: 'Avena cremosa con fruta fresca y semillas.',
                  calories: (calories * .24).round(),
                  proteinGrams: calories * .24 * .18 / 4,
                  carbsGrams: calories * .24 * .62 / 4,
                  fatGrams: calories * .24 * .20 / 9,
                  fiberGrams: 9,
                  serving: '1 tazón',
                  prepMinutes: 12,
                  ingredients: const [
                    MealIngredient(name: 'Avena en hojuelas', amount: '45 g'),
                    MealIngredient(
                      name: 'Leche semidesnatada',
                      amount: '180 ml',
                    ),
                    MealIngredient(name: 'Fresas', amount: '50 g'),
                    MealIngredient(name: 'Arándanos', amount: '40 g'),
                    MealIngredient(name: 'Semillas de chía', amount: '10 g'),
                  ],
                  steps: const [
                    'Lava las fresas y los arándanos con agua corriente; corta las fresas en láminas.',
                    'Calienta la leche en una olla pequeña a fuego medio durante 2 minutos, sin dejar que hierva.',
                    'Añade la avena y cocina de 5 a 7 minutos a fuego bajo, removiendo cada 30 segundos hasta que quede cremosa.',
                    'Sirve la avena en un tazón, distribuye las fresas, los arándanos y las semillas de chía por encima.',
                  ],
                  vitamins: const [
                    NutrientItem(name: 'Vitamina C', amount: '35 mg'),
                    NutrientItem(name: 'Vitamina B1', amount: '0.3 mg'),
                  ],
                  minerals: const [
                    NutrientItem(name: 'Calcio', amount: '230 mg'),
                    NutrientItem(name: 'Magnesio', amount: '95 mg'),
                  ],
                  nutritionNotes: 'Valores nutricionales aproximados por porción; pueden variar según la leche elegida.',
                  allergensAndPrecautions: 'Contiene leche. La avena puede contener gluten si no está certificada como libre de gluten.',
                ),
                MenuMeal(
                  id: '${day.toLowerCase()}-almuerzo',
                  type: 'Almuerzo',
                  name: 'Bowl de pollo, quinoa y aguacate',
                  description: 'Pollo a la plancha con quinoa, aguacate y vegetales frescos.',
                  calories: (calories * .36).round(),
                  proteinGrams: calories * .36 * .28 / 4,
                  carbsGrams: calories * .36 * .47 / 4,
                  fatGrams: calories * .36 * .25 / 9,
                  fiberGrams: 11,
                  serving: '1 bowl',
                  prepMinutes: 30,
                  ingredients: const [
                    MealIngredient(name: 'Pechuga de pollo', amount: '120 g'),
                    MealIngredient(name: 'Quinoa cocida', amount: '¾ taza'),
                    MealIngredient(name: 'Aguacate', amount: '¼ unidad'),
                    MealIngredient(name: 'Tomates cherry', amount: '80 g'),
                    MealIngredient(name: 'Espinaca fresca', amount: '1 taza'),
                    MealIngredient(
                      name: 'Aceite de oliva',
                      amount: '1 cucharadita',
                    ),
                  ],
                  steps: const [
                    'Enjuaga la quinoa y cocínala con el doble de agua, tapada a fuego bajo, durante 15 minutos; deja reposar 5 minutos.',
                    'Sazona el pollo con una pizca de sal, pimienta y jugo de limón. Calienta una sartén antiadherente a fuego medio-alto durante 2 minutos.',
                    'Cocina el pollo 5 o 6 minutos por cada lado, hasta que el centro alcance 74 °C o no presente partes rosadas. Déjalo reposar 3 minutos y córtalo.',
                    'Lava la espinaca y los tomates; corta los tomates por la mitad y el aguacate en láminas.',
                    'Arma el bowl con quinoa, espinaca, pollo, tomates y aguacate. Termina con el aceite de oliva.',
                  ],
                  vitamins: const [
                    NutrientItem(name: 'Vitamina K', amount: '120 µg'),
                    NutrientItem(name: 'Vitamina C', amount: '22 mg'),
                  ],
                  minerals: const [
                    NutrientItem(name: 'Hierro', amount: '3.8 mg'),
                    NutrientItem(name: 'Potasio', amount: '980 mg'),
                  ],
                  nutritionNotes: 'Valores aproximados por porción; el contenido de sodio cambia según el condimento usado.',
                  allergensAndPrecautions: 'No se identifican alérgenos comunes en la receta base. Revisa contaminación cruzada en la quinoa y los condimentos.',
                ),
                MenuMeal(
                  id: '${day.toLowerCase()}-snack',
                  type: 'Snack',
                  name: 'Yogur griego con nueces y banano',
                  description:
                      'Yogur natural con banano fresco y nueces de nogal.',
                  calories: (calories * .12).round(),
                  proteinGrams: calories * .12 * .12 / 4,
                  carbsGrams: calories * .12 * .55 / 4,
                  fatGrams: calories * .12 * .33 / 9,
                  fiberGrams: 4,
                  serving: '1 porción',
                  prepMinutes: 3,
                  ingredients: const [
                    MealIngredient(
                      name: 'Yogur griego natural',
                      amount: '170 g',
                    ),
                    MealIngredient(name: 'Banano', amount: '½ unidad'),
                    MealIngredient(name: 'Nueces de nogal', amount: '15 g'),
                  ],
                  steps: const [
                    'Lava y pela el banano; córtalo en rodajas de aproximadamente 1 cm.',
                    'Sirve el yogur griego frío en un recipiente.',
                    'Añade las rodajas de banano y distribuye las nueces de nogal por encima antes de consumir.',
                  ],
                  vitamins: const [
                    NutrientItem(name: 'Vitamina B6', amount: '0.3 mg'),
                    NutrientItem(name: 'Vitamina B12', amount: '0.8 µg'),
                  ],
                  minerals: const [
                    NutrientItem(name: 'Calcio', amount: '190 mg'),
                    NutrientItem(name: 'Potasio', amount: '460 mg'),
                  ],
                  nutritionNotes: 'Valores aproximados por porción; el aporte proteico varía entre marcas de yogur.',
                  allergensAndPrecautions: 'Contiene leche y nueces. Sustituye por yogur vegetal y semillas si tienes alergia o intolerancia.',
                ),
                MenuMeal(
                  id: '${day.toLowerCase()}-cena',
                  type: 'Cena',
                  name: 'Salmón al horno con brócoli y zanahoria',
                  description: 'Salmón horneado con vegetales asados y limón.',
                  calories: (calories * .28).round(),
                  proteinGrams: calories * .28 * .30 / 4,
                  carbsGrams: calories * .28 * .35 / 4,
                  fatGrams: calories * .28 * .35 / 9,
                  fiberGrams: 8,
                  serving: '1 plato',
                  prepMinutes: 28,
                  ingredients: const [
                    MealIngredient(name: 'Filete de salmón', amount: '130 g'),
                    MealIngredient(name: 'Brócoli', amount: '1 taza'),
                    MealIngredient(
                      name: 'Zanahoria',
                      amount: '1 unidad pequeña',
                    ),
                    MealIngredient(name: 'Calabacín', amount: '½ unidad'),
                    MealIngredient(
                      name: 'Aceite de oliva',
                      amount: '1 cucharadita',
                    ),
                    MealIngredient(name: 'Limón', amount: '½ unidad'),
                  ],
                  steps: const [
                    'Precalienta el horno a 200 °C. Lava el brócoli, la zanahoria y el calabacín; corta la zanahoria y el calabacín en medias lunas.',
                    'Coloca los vegetales en una bandeja, mézclalos con la mitad del aceite, una pizca de sal y pimienta. Hornea 10 minutos.',
                    'Seca el salmón con papel de cocina, condiméntalo con pimienta, ralladura de limón y el aceite restante.',
                    'Añade el salmón a la bandeja y hornea de 10 a 12 minutos más, hasta que se desmenuce fácilmente con un tenedor.',
                    'Sirve el salmón con los vegetales y termina con jugo de limón recién exprimido.',
                  ],
                  vitamins: const [
                    NutrientItem(name: 'Vitamina D', amount: '12 µg'),
                    NutrientItem(name: 'Vitamina A', amount: '620 µg'),
                  ],
                  minerals: const [
                    NutrientItem(name: 'Selenio', amount: '52 µg'),
                    NutrientItem(name: 'Potasio', amount: '850 mg'),
                  ],
                  nutritionNotes: 'Valores aproximados por porción; el contenido de omega-3 puede variar según el tipo de salmón.',
                  allergensAndPrecautions: 'Contiene pescado. Verifica que el salmón esté completamente cocido y evita contaminación cruzada con otros alérgenos.',
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

int _asInt(dynamic value) =>
    value is num ? value.round() : int.tryParse(value?.toString() ?? '') ?? 0;

double _asDouble(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return null;
}
