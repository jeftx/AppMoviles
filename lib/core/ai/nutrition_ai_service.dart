import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import 'nutrition_models.dart';

class NutritionAiService {
  NutritionAiService._();

  static final _model = _createModel('gemini-3.8-flash');
  static final _fallbackModel = _createModel('gemini-4-argon');

  /// Comprueba una sola solicitud pequeña sin enviar el perfil del usuario.
  static Future<String> testMenuConnection() async {
    final watch = Stopwatch()..start();
    try {
      final response = await _model
          .generateContent([
            Content.text(
              'Devuelve solo JSON con este formato: '
              '{"nombre":"Arepa con huevo","ingredientes":["arepa","huevo"]}.',
            ),
          ])
          .timeout(const Duration(seconds: 45));
      final json = _decodeResponse(response);
      if (json['nombre'] is! String || json['ingredientes'] is! List) {
        throw const FormatException(
          'Gemini respondió, pero el JSON de prueba está incompleto.',
        );
      }
      return 'Gemini respondió a la prueba en ${watch.elapsed.inSeconds} segundos. '
          'La prueba usó datos ficticios y no creó ni modificó menús.';
    } on TimeoutException {
      return 'La prueba pequeña de Gemini no respondió en 45 segundos. '
          'No se modificó tu menú. La causa puede ser el servicio o la conexión.';
    } catch (error) {
      return 'Falló la prueba pequeña de Gemini: ${menuMessageFor(error)}';
    }
  }

  /// Prueba aislada: una receta detallada, sin guardar ni alterar el menú.
  static Future<MenuMeal> testDetailedMeal(UserNutritionProfile profile) async {
    final response = await _model
        .generateContent([
          Content.text('''
Genera una receta de desayuno orientativa para este perfil JSON:
${profile.promptSummary}
Usa ingredientes concretos y cantidades con unidades. Respeta las restricciones
e indicaciones de salud; usa nombres habituales del país indicado y evita
anglicismos. Incluye pasos completos con tiempos y niveles de fuego cuando
corresponda. Los nutrientes son estimaciones, no datos verificados ni consejo
médico. Menciona alérgenos y precauciones sin garantizar ausencia de riesgos.
Devuelve solo un objeto JSON con esta estructura, sustituyendo los ejemplos:
{"type":"Desayuno","name":"nombre","description":"descripción",
"calories":350,"proteinGrams":15,"carbsGrams":40,"fatGrams":10,
"fiberGrams":5,"serving":"1 porción","prepMinutes":15,
"ingredients":[{"name":"avena","amount":"40 g"}],
"steps":["paso detallado"],
"vitamins":[{"name":"Vitamina C","amount":"10 mg"}],
"minerals":[{"name":"Hierro","amount":"2 mg"}],
"nutritionNotes":"Valores aproximados por porción.",
"allergensAndPrecautions":"Precauciones y alérgenos de la receta"}
Incluye al menos tres ingredientes y tres pasos concretos.
'''),
        ])
        .timeout(const Duration(seconds: 90));
    final meal = MenuMeal.fromJson(_decodeResponse(response));
    if (meal.type.trim().toLowerCase() != 'desayuno' ||
        meal.name.trim().isEmpty ||
        meal.ingredients.length < 3 ||
        meal.steps.length < 3 ||
        meal.vitamins.isEmpty ||
        meal.minerals.isEmpty ||
        meal.allergensAndPrecautions.trim().isEmpty) {
      throw const FormatException(
        'La comida llegó incompleta: faltan ingredientes, pasos, nutrientes o precauciones.',
      );
    }
    return meal;
  }

  static GenerativeModel _createModel(
    String model, {
    bool lowThinking = false,
  }) => FirebaseAI.googleAI().generativeModel(
    model: model,
    generationConfig: GenerationConfig(
      temperature: 0.2,
      responseMimeType: 'application/json',
      maxOutputTokens: 16384,
      thinkingConfig: lowThinking
          ? ThinkingConfig.withThinkingLevel(ThinkingLevel.low)
          : null,
    ),
    systemInstruction: Content.system(
      'Eres un asistente nutricional. Devuelve estimaciones prudentes, usa '
      'español y nunca presentes una estimación como diagnóstico médico.',
    ),
  );

  static Future<FoodAnalysis> analyzeMealPhoto(Uint8List imageBytes) async {
    final response = await _generateWithFallback([
      Content.multi([
        const TextPart('''
Analiza esta foto de un plato de comida. Identifica solamente los alimentos
visibles y estima una porción razonable en gramos y sus calorías. No inventes
ingredientes que no se vean. Devuelve exclusivamente un objeto JSON con esta
estructura:
{
  "foods": [
    {"name": "string", "calories": 0, "portionGrams": 0, "notes": "string"}
  ],
  "totalCalories": 0,
  "summary": "string",
  "confidenceNote": "Explica brevemente que las porciones y calorías son aproximadas."
}
Si no se observa un plato o los alimentos no se distinguen, devuelve foods
vacío, totalCalories 0 y explica cómo tomar una foto más clara.'''),
        InlineDataPart('image/jpeg', imageBytes),
      ]),
    ]);

    return FoodAnalysis.fromJson(_decodeResponse(response));
  }

  static Future<GeneratedMenu> generateMenu(
    UserNutritionProfile profile,
  ) async {
    final response = await _generateWithFallback([
      Content.text('''
Genera un menú saludable de un día para esta persona:
${profile.promptSummary}

Respeta estrictamente las restricciones. Propón desayuno, almuerzo, cena y un
snack, con ingredientes habituales y cantidades razonables. Para cada comida
indica ingredientes específicos, macros, fibra, vitaminas, minerales,
alérgenos y pasos completos con tiempos, temperatura y técnica cuando aplique.
Devuelve
exclusivamente JSON con esta estructura:
{
  "title": "string",
  "dailyCalories": 0,
  "rationale": "string",
  "meals": [
    {"type": "Desayuno", "name": "string", "description": "string", "calories": 0}
  ]
}
Aclara en rationale que la propuesta es orientativa y no sustituye la
recomendación de un profesional de nutrición.'''),
    ]);

    return GeneratedMenu.fromJson(_decodeResponse(response));
  }

  /// Propuesta breve de un día; las recetas se solicitan por separado.
  static Future<WeeklyMenuDay> generateDailyOutline(
    UserNutritionProfile profile,
  ) async {
    final response = await _model
        .generateContent([
          Content.text('''
Propón cuatro comidas para un día: Desayuno, Almuerzo, Snack y Cena.
Perfil: ${profile.promptSummary}
Adapta los nombres y alimentos a la gastronomía y lenguaje cotidianos del país.
Respeta restricciones y notas de salud; no inventes ingredientes genéricos.
Para Colombia evita anglicismos como bowl. Cada una de las cuatro comidas debe
contener exactamente un alimento de cada categoría: ensalada, carbohidrato,
proteina y jugo; opcionalmente agrega sopa, fruta, verdura o snack. Solo usa
las categorías ensalada, carbohidrato, proteina, jugo, sopa, fruta, verdura y snack.
Especifica alimentos y una porción en cada nombre; evita bebidas azucaradas y
respeta las restricciones. Incluye calorías estimadas por alimento, sin recetas.
Las calorías son aproximadas y no sustituyen una evaluación profesional.
Los números siguientes son ejemplos de formato; estima valores según cada
receta y el perfil, teniendo en cuenta la meta calórica diaria.
Devuelve exclusivamente JSON con esta forma:
{"meals":[{"type":"Desayuno","name":"nombre específico","description":"descripción breve","foods":[{"category":"ensalada","name":"alimento y porción","calories":50},{"category":"carbohidrato","name":"alimento y porción","calories":100},{"category":"proteina","name":"alimento y porción","calories":100},{"category":"jugo","name":"alimento y porción","calories":80}]},
{"type":"Almuerzo","name":"nombre específico","description":"descripción breve","foods":[...]},
{"type":"Snack","name":"nombre específico","description":"descripción breve","foods":[...]},
{"type":"Cena","name":"nombre específico","description":"descripción breve","foods":[...]}]}
Sustituye los puntos suspensivos con listas completas; no omitas categorías.
'''),
        ])
        .timeout(const Duration(seconds: 60));
    return parseDailyOutline(_decodeResponse(response));
  }

  /// Comprueba la estructura antes de permitir guardar una propuesta diaria.
  static WeeklyMenuDay parseDailyOutline(Map<String, dynamic> json) {
    final rawMeals = json['meals'];
    if (rawMeals is! List || rawMeals.length != 4) {
      throw const FormatException(
        'La IA no devolvió las cuatro comidas del día.',
      );
    }
    const types = {'desayuno', 'almuerzo', 'snack', 'cena'};
    final meals = <MenuMeal>[];
    final found = <String>{};
    for (final item in rawMeals) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Una comida tiene un formato incorrecto.');
      }
      final type = item['type'];
      final name = item['name'];
      final description = item['description'];
      final rawFoods = item['foods'];
      if (type is! String ||
          !types.contains(type.trim().toLowerCase()) ||
          !found.add(type.trim().toLowerCase()) ||
          name is! String ||
          name.trim().isEmpty ||
          description is! String ||
          description.trim().isEmpty ||
          rawFoods is! List ||
          rawFoods.isEmpty) {
        throw const FormatException(
          'El menú diario contiene una comida incompleta.',
        );
      }
      final foods = <MenuFoodItem>[];
      final categories = <FoodCategory>{};
      for (final raw in rawFoods) {
        if (raw is! Map<String, dynamic> ||
            raw['name'] is! String ||
            (raw['name'] as String).trim().isEmpty ||
            raw['category'] is! String ||
            raw['calories'] is! num) {
          throw const FormatException('La IA devolvió un alimento incompleto.');
        }
        final category = FoodCategory.parse(raw['category'] as String);
        final calories = raw['calories'] as num;
        if (category == null ||
            category == FoodCategory.guiso ||
            category == FoodCategory.otro ||
            !calories.isFinite ||
            calories < 1 ||
            !categories.add(category)) {
          throw const FormatException(
            'La IA devolvió una categoría inválida o repetida, o calorías inválidas.',
          );
        }
        foods.add(
          MenuFoodItem(
            name: (raw['name'] as String).trim(),
            category: category,
            calories: calories.round(),
          ),
        );
      }
      if (!categories.containsAll({
        FoodCategory.ensalada,
        FoodCategory.carbohidrato,
        FoodCategory.proteina,
        FoodCategory.jugo,
      })) {
        throw const FormatException(
          'La comida no incluye ensalada, carbohidrato, proteína y jugo.',
        );
      }
      meals.add(
        MenuMeal(
          id: '${DateTime.now().microsecondsSinceEpoch}-${type.trim().toLowerCase()}',
          type: type.trim(),
          name: name.trim(),
          description: description.trim(),
          calories: foods.fold(0, (sum, food) => sum + food.calories),
          foods: foods,
        ),
      );
    }
    return WeeklyMenuDay(day: 'Hoy', meals: meals, source: 'ai');
  }

  /// Genera los detalles de la propuesta elegida sin cambiar su identidad.
  static Future<MenuMeal> generateMealDetails(
    UserNutritionProfile profile,
    MenuMeal outline,
  ) async {
    final response = await _model
        .generateContent([
          Content.text('''
Desarrolla la receta exacta propuesta a continuación, adaptándola al perfil.
Perfil: ${profile.promptSummary}
Comida: ${jsonEncode({'type': outline.type, 'name': outline.name, 'description': outline.description})}
Respeta las restricciones y notas de salud. Usa nombres cotidianos del país,
ingredientes concretos con cantidad y unidad, y pasos claros con tiempos y fuego.
Incluye alérgenos y precauciones. Los nutrientes son estimaciones por porción,
no datos verificados ni consejos médicos. No cambies el nombre ni tipo del plato.
Devuelve solo JSON con las claves: type, name, description, calories,
proteinGrams, carbsGrams, fatGrams, fiberGrams, serving, prepMinutes,
ingredients (objetos con name y amount), steps (textos), vitamins y minerals
(objetos con name y amount), nutritionNotes y allergensAndPrecautions.
Incluye al menos tres ingredientes específicos y tres pasos concretos.
'''),
        ])
        .timeout(const Duration(seconds: 90));
    final data = _decodeResponse(response);
    final name = data['name'];
    if (name is! String ||
        name.trim().toLowerCase() != outline.name.trim().toLowerCase()) {
      throw const FormatException('La IA cambió la comida solicitada.');
    }
    for (final key in [
      'calories',
      'proteinGrams',
      'carbsGrams',
      'fatGrams',
      'fiberGrams',
      'prepMinutes',
    ]) {
      final value = data[key];
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException(
          'La receta no incluye valores nutricionales completos.',
        );
      }
    }
    final meal = MenuMeal.fromJson({
      ...data,
      'id': outline.id,
      'type': outline.type,
      'name': outline.name,
    });
    if (meal.ingredients.length < 3 ||
        meal.steps.length < 3 ||
        meal.ingredients.any(
          (item) => item.name.trim().isEmpty || item.amount.trim().isEmpty,
        ) ||
        meal.vitamins.isEmpty ||
        meal.minerals.isEmpty ||
        meal.vitamins.any(
          (item) => item.name.trim().isEmpty || item.amount.trim().isEmpty,
        ) ||
        meal.minerals.any(
          (item) => item.name.trim().isEmpty || item.amount.trim().isEmpty,
        ) ||
        meal.calories <= 0 ||
        meal.prepMinutes <= 0 ||
        meal.allergensAndPrecautions.trim().isEmpty) {
      throw const FormatException(
        'La receta llegó incompleta. Inténtalo de nuevo.',
      );
    }
    return meal;
  }

  static Future<WeeklyMenu> generateWeeklyMenu(
    UserNutritionProfile profile, {
    void Function(int completed, int total)? onProgress,
  }) => _generateWeeklyMenu(profile, onProgress: onProgress);

  /// Realiza la misma solicitud del primer día, sin guardar su resultado.
  static Future<WeeklyMenuDay> testFullMenuDay(
    UserNutritionProfile profile, {
    void Function(String stage)? onStage,
  }) async {
    final menu = await _generateWeeklyMenu(
      profile,
      firstDayOnly: true,
      onStage: onStage,
    );
    return menu.days.single;
  }

  static Future<WeeklyMenu> _generateWeeklyMenu(
    UserNutritionProfile profile, {
    void Function(int completed, int total)? onProgress,
    bool firstDayOnly = false,
    void Function(String stage)? onStage,
  }) async {
    const dayNames = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final days = <WeeklyMenuDay>[];
    for (final dayName in dayNames) {
      final usedMeals = days
          .expand((day) => day.meals)
          .map((meal) => '${meal.type}: ${meal.name}')
          .toList();
      final meals = <MenuMeal>[];
      const portions = {
        'Desayuno': 0.25,
        'Almuerzo': 0.35,
        'Snack': 0.12,
        'Cena': 0.28,
      };
      for (final mealType in portions.keys) {
        final targetCalories = (profile.dailyCalorieGoal * portions[mealType]!)
            .round();
        final previousNames = [
          ...usedMeals,
          ...meals.map((meal) => '${meal.type}: ${meal.name}'),
        ];
        onStage?.call('Generando $mealType (${meals.length + 1} de 4)');
        final response = await _generateWithFallback(
          [
            Content.text(
              '''
Genera solo una comida de tipo $mealType para el $dayName, para esta persona:
${profile.promptSummary}

Respeta estrictamente las restricciones y cualquier condición de salud indicada.
Cocina según el país o región indicada: incorpora de forma saludable platos,
ingredientes y técnicas habituales de su gastronomía. Evita repetir el mismo
cereal, proteína o preparación; en particular, no uses cereal como base de más
de dos comidas durante toda la semana. Varía desayunos, almuerzos, cenas y
snacks, manteniendo recetas prácticas y reconocibles para esa cultura.
Usa español y nombres cotidianos del país indicado. Para Colombia evita
anglicismos como "bowl": nombra la preparación de forma reconocible, por
ejemplo "arroz con fríjoles" o "ensalada" si realmente es una ensalada.
Devuelve solo una comida de tipo $mealType en el día $dayName, con un objetivo
aproximado de $targetCalories kcal para esta comida; no la meta del día completo.
Evita repetir estos platos ya propuestos: ${jsonEncode(previousNames)}.
Usa ingredientes
habituales, porciones razonables y recetas realistas. Cada ingrediente DEBE ser
concreto: nunca uses términos genéricos como “fruta”, “frutos rojos”, “frutos
secos”, “proteína”, “verduras” o “cereal”. Por ejemplo, especifica “fresas y
arándanos”, “nueces de nogal y almendras”, “pechuga de pollo” o “brócoli y
zanahoria”, con cantidades individuales cuando corresponda.
No repitas ninguna receta ni su título de días anteriores.

Los pasos también deben ser ejecutables y completos: no escribas “cocina hasta
que esté lista”. Indica preparación previa, condimentos, técnica, temperatura
(°C o nivel de fuego), tiempo aproximado, orden de incorporación y punto de
cocción. Incluye entre 3 y 7 pasos por receta; no omitas lavado, picado,
precalentado o reposo cuando sean necesarios.

Las calorías, macros, fibra, vitaminas y minerales son estimaciones por
porción. Decláralas como aproximadas y no presentes recomendaciones como
diagnóstico médico. Enumera alérgenos y precauciones relevantes para esa receta
y las restricciones, aunque el texto sea “No se identifican alérgenos comunes
en esta preparación”. Devuelve exclusivamente JSON con esta estructura:
{
  "dailyCalories": 0,
  "source": "ai",
  "days": [
    {
      "day": "$dayName",
      "meals": [
        {
          "id": "$dayName-$mealType",
          "type": "$mealType",
          "name": "string",
          "description": "string",
          "calories": 0,
          "proteinGrams": 0,
          "carbsGrams": 0,
          "fatGrams": 0,
          "fiberGrams": 0,
          "serving": "string",
          "prepMinutes": 0,
          "ingredients": [{"name": "string", "amount": "string"}],
          "steps": ["string"],
          "vitamins": [{"name": "Vitamina C", "amount": "0 mg"}],
          "minerals": [{"name": "Hierro", "amount": "0 mg"}],
          "nutritionNotes": "Estimaciones nutricionales aproximadas por porción.",
          "allergensAndPrecautions": "string"
        }
      ]
    }
  ]
}
Incluye cantidades y macros plausibles y respeta las restricciones alimentarias.''',
            ),
          ],
          retryCount: 0,
          useFallback: false,
        ).timeout(const Duration(seconds: 90));
        onStage?.call('Leyendo $mealType');
        final decoded = _decodeResponse(response);
        final result = WeeklyMenu.fromJson(decoded);
        if (result.days.length != 1 ||
            result.days.first.day.trim().toLowerCase() !=
                dayName.toLowerCase()) {
          throw FormatException(
            'La IA no devolvió el menú de $dayName. Inténtalo de nuevo.',
          );
        }
        final returnedMeals = result.days.first.meals;
        if (returnedMeals.length != 1 ||
            returnedMeals.first.type.trim().toLowerCase() !=
                mealType.toLowerCase() ||
            returnedMeals.any(
              (meal) =>
                  meal.name.trim().isEmpty ||
                  meal.ingredients.length < 3 ||
                  meal.steps.length < 3 ||
                  meal.vitamins.isEmpty ||
                  meal.minerals.isEmpty ||
                  meal.allergensAndPrecautions.trim().isEmpty,
            )) {
          throw FormatException(
            '$mealType de $dayName llegó incompleto. El menú anterior se conserva.',
          );
        }
        if (returnedMeals.any(
          (meal) => days
              .expand((day) => day.meals)
              .any(
                (previous) =>
                    previous.type.trim().toLowerCase() ==
                        meal.type.trim().toLowerCase() &&
                    previous.name.trim().toLowerCase() ==
                        meal.name.trim().toLowerCase(),
              ),
        )) {
          throw FormatException(
            'La IA repitió una comida en $dayName. El menú anterior se conserva.',
          );
        }
        meals.add(returnedMeals.single);
      }
      days.add(WeeklyMenuDay(day: dayName, meals: meals));
      onProgress?.call(days.length, dayNames.length);
      if (firstDayOnly) {
        return WeeklyMenu(
          dailyCalories: profile.dailyCalorieGoal,
          source: 'ai',
          days: days,
        );
      }
    }
    final weeklyMenu = WeeklyMenu(
      dailyCalories: profile.dailyCalorieGoal,
      source: 'ai',
      days: days,
    );
    _validateWeeklyMenu(weeklyMenu);
    return weeklyMenu;
  }

  static String userMessageFor(Object error) =>
      _knownMessageFor(error) ??
      'No pudimos analizar la foto. Verifica tu conexión e inténtalo de nuevo.';

  static String menuMessageFor(Object error) {
    if (error is TimeoutException) {
      return 'Tiempo de espera agotado: ${error.message ?? 'Gemini no respondió a tiempo.'}';
    }
    if (error is FirebaseAIException) {
      return '${error.runtimeType}: ${_sanitizeError(error.message)}';
    }
    if (error is FormatException) {
      return 'Respuesta inválida: ${_sanitizeError(error.message)}';
    }
    if (error is StateError) return _sanitizeError(error.message.toString());
    return '${error.runtimeType}: ${_sanitizeError(error.toString())}';
  }

  static String _sanitizeError(String text) => text
      .replaceAll(RegExp(r'https?://[^\s]+'), '[dirección omitida]')
      .replaceAllMapped(
        RegExp(
          r'(api[_-]?key|key|token)\s*[=:]\s*[^\s,}]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}=[oculto]',
      );

  /// Diagnóstico limitado a metadatos; no incluye perfiles ni respuestas del modelo.
  static String menuDiagnosticFor(Object error) {
    if (error is TimeoutException) return 'Tiempo de espera agotado.';
    if (error.runtimeType.toString() == 'ClientException') {
      // Examina solo términos conocidos y nunca muestra la URL ni el contenido.
      final details = error.toString().toLowerCase();
      if (details.contains('connection closed') ||
          details.contains('connection reset') ||
          details.contains('broken pipe') ||
          details.contains('connection terminated')) {
        return 'Tipo: ClientException. La conexión se cerró antes de recibir la respuesta completa.';
      }
      if (details.contains('failed host lookup') ||
          details.contains('name or service not known') ||
          details.contains('no address associated with hostname')) {
        return 'Tipo: ClientException. No se pudo resolver la dirección del servicio.';
      }
      if (details.contains('timed out') || details.contains('timeout')) {
        return 'Tipo: ClientException. La comunicación agotó su tiempo de espera.';
      }
      if (details.contains('handshake') || details.contains('certificate')) {
        return 'Tipo: ClientException. Falló la conexión segura con el servicio.';
      }
      return 'Tipo: ClientException. Ocurrió un error de comunicación; el detalle no está clasificado.';
    }
    if (error is FirebaseAIException) {
      final status = RegExp(r'\b(?:400|401|403|404|429|500|502|503|504)\b')
          .firstMatch(error.message)
          ?.group(0);
      return 'Tipo: ${error.runtimeType}${status == null ? '' : ', código $status'}.';
    }
    if (error is FirebaseAISdkException) {
      return 'Tipo: FirebaseAISdkException (el SDK no pudo procesar la respuesta).';
    }
    return 'Tipo: ${error.runtimeType}.';
  }

  static Duration retryDelayFor(Object error) => switch (error) {
    QuotaExceeded() => const Duration(minutes: 5),
    ServerException(:final message)
        when message.toLowerCase().contains('high demand') =>
      const Duration(minutes: 1),
    _ => const Duration(seconds: 30),
  };

  static String? _knownMessageFor(Object error) {
    return switch (error) {
      ServiceApiNotEnabled() =>
        'La IA todavía no está activada para este proyecto. En Firebase Console '
            'abre Firebase AI Logic, pulsa "Get started", selecciona Gemini '
            'Developer API y espera unos minutos antes de reintentar.',
      InvalidApiKey() =>
        'La clave de Firebase no está autorizada para usar Gemini. Revisa la '
            'configuración de Firebase AI Logic del proyecto.',
      QuotaExceeded() =>
        'Se alcanzó el límite temporal de solicitudes de IA. Inténtalo de nuevo '
            'más tarde.',
      ServerException(:final message)
          when message.toLowerCase().contains('high demand') =>
        'Gemini tiene alta demanda en este momento. Espera unos minutos e '
            'inténtalo nuevamente.',
      UnsupportedUserLocation() =>
        'El servicio de IA no está disponible para la ubicación configurada.',
      FirebaseAIException(:final message) => 'Firebase AI respondió: $message',
      FormatException(:final message) => message,
      StateError(:final message) => message,
      _ => null,
    };
  }

  static Map<String, dynamic> _decodeResponse(
    GenerateContentResponse response,
  ) {
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw StateError('La IA no devolvió un resultado para esta solicitud.');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'La respuesta de IA no tiene el formato esperado.',
      );
    }
    return decoded;
  }

  static Future<T> _runWithRetry<T>(
    Future<T> Function() request, {
    int retryCount = 2,
  }) async {
    const delays = [Duration(seconds: 2), Duration(seconds: 4)];
    final attempts = retryCount.clamp(0, delays.length);

    for (var attempt = 0; attempt <= attempts; attempt++) {
      try {
        return await request();
      } on ServerException catch (error) {
        if (!_isHighDemand(error) || attempt == attempts) rethrow;
        await Future<void>.delayed(delays[attempt]);
      }
    }

    throw StateError('No se pudo completar la solicitud de IA.');
  }

  static Future<GenerateContentResponse> _generateWithFallback(
    List<Content> prompt, {
    int retryCount = 2,
    bool useFallback = true,
    GenerativeModel? primaryModel,
  }) async {
    try {
      return await _runWithRetry(
        () => (primaryModel ?? _model).generateContent(prompt),
        retryCount: retryCount,
      );
    } on ServerException catch (error) {
      if (!_isHighDemand(error) || !useFallback) rethrow;
      return _runWithRetry(
        () => _fallbackModel.generateContent(prompt),
        retryCount: retryCount,
      );
    }
  }

  static bool _isHighDemand(ServerException error) =>
      error.message.toLowerCase().contains('high demand');

  static void _validateWeeklyMenu(WeeklyMenu weeklyMenu) {
    const requiredTypes = {'desayuno', 'almuerzo', 'snack', 'cena'};
    if (weeklyMenu.days.length != 7) {
      throw const FormatException(
        'La IA no creó los siete días completos. Intenta generar el menú de nuevo.',
      );
    }

    final namesByType = <String, Set<String>>{
      for (final type in requiredTypes) type: <String>{},
    };
    for (final day in weeklyMenu.days) {
      final dayTypes = day.meals.map((meal) => meal.type.toLowerCase()).toSet();
      if (!dayTypes.containsAll(requiredTypes)) {
        throw const FormatException(
          'La IA no incluyó las cuatro comidas en todos los días. Intenta de nuevo.',
        );
      }
      for (final meal in day.meals) {
        final type = meal.type.toLowerCase();
        if (!requiredTypes.contains(type)) continue;
        if (meal.ingredients.length < 3 ||
            meal.steps.length < 3 ||
            meal.vitamins.isEmpty ||
            meal.minerals.isEmpty ||
            meal.allergensAndPrecautions.trim().isEmpty) {
          throw const FormatException(
            'La IA devolvió recetas incompletas. Vuelve a generar el menú para obtener el detalle completo.',
          );
        }
        namesByType[type]!.add(meal.name.trim().toLowerCase());
      }
    }
    if (namesByType.values.any((names) => names.length < 7)) {
      throw const FormatException(
        'La IA repitió recetas durante la semana. Vuelve a generar el menú para obtener opciones diferentes cada día.',
      );
    }
  }
}
