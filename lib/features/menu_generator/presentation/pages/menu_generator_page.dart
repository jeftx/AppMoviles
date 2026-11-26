import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/ai/nutrition_ai_service.dart';
import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/nutrition_profile_repository.dart';

class MenuGeneratorPage extends StatefulWidget {
  const MenuGeneratorPage({super.key});

  @override
  State<MenuGeneratorPage> createState() => _MenuGeneratorPageState();
}

class _MenuGeneratorPageState extends State<MenuGeneratorPage> {
  final _repository = NutritionProfileRepository();
  UserNutritionProfile? _profile;
  WeeklyMenu? _weeklyMenu;
  String? _error;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isTestingAi = false;
  bool _isTestingDay = false;
  String _dayTestStage = 'Preparando solicitud';
  bool _isTestingMeal = false;
  String? _aiTestResult;
  WeeklyMenuDay? _testDay;
  MenuMeal? _testMeal;
  DateTime? _nextAiAttempt;

  bool get _isAiCoolingDown => _nextAiAttempt?.isAfter(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await _repository.watch(user.uid).first;
      final daily = await _repository
          .watchDailyMenu(
            user.uid,
            NutritionProfileRepository.dateKey(DateTime.now()),
          )
          .first;
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _weeklyMenu = daily == null
            ? profile?.weeklyMenu
            : WeeklyMenu(
                dailyCalories: profile?.dailyCalorieGoal ?? 0,
                source: 'ai_daily',
                days: [daily],
              );
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'No pudimos cargar tu perfil.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createMenu({required bool withAi}) async {
    final user = FirebaseAuth.instance.currentUser;
    final profile = _profile;
    if (user == null || profile == null) return;
    if (withAi && _isAiCoolingDown) {
      setState(
        () => _error =
            'Espera un momento antes de volver a solicitar un menú con IA.',
      );
      return;
    }
    if (!profile.hasProfileDetails || profile.country.trim().isEmpty) {
      setState(
        () => _error = 'Se requieren edad, estatura, peso y país para crear un menú personalizado.',
      );
      return;
    }
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final date = NutritionProfileRepository.dateKey(DateTime.now());
      final WeeklyMenu weeklyMenu;
      if (withAi) {
        final day = await NutritionAiService.generateDailyOutline(profile);
        if (date != NutritionProfileRepository.dateKey(DateTime.now())) {
          throw StateError(
            'La fecha cambió durante la generación. Vuelve a intentarlo.',
          );
        }
        if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
          throw StateError('La sesión cambió durante la generación.');
        }
        await _repository.saveDailyMenu(user.uid, date, day);
        weeklyMenu = WeeklyMenu(
          dailyCalories: profile.dailyCalorieGoal,
          source: 'ai_daily',
          days: [day],
        );
      } else {
        weeklyMenu = WeeklyMenu.fallback(profile);
        await _repository.saveWeeklyMenu(user.uid, weeklyMenu);
      }
      if (!mounted) {
        return;
      }
      setState(() => _weeklyMenu = weeklyMenu);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            withAi ? 'Tu menú de hoy fue guardado.' : 'Tu guía fue guardada.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = NutritionAiService.menuMessageFor(error));
        if (withAi) _startAiCooldown(NutritionAiService.retryDelayFor(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _startAiCooldown(Duration delay) {
    final retryAt = DateTime.now().add(delay);
    setState(() => _nextAiAttempt = retryAt);
    Future<void>.delayed(delay, () {
      if (mounted && _nextAiAttempt == retryAt) {
        setState(() => _nextAiAttempt = null);
      }
    });
  }

  Future<void> _testAi() async {
    if (_isGenerating || _isTestingAi || _isTestingDay || _isTestingMeal) {
      return;
    }
    setState(() {
      _isTestingAi = true;
      _aiTestResult = null;
    });
    final result = await NutritionAiService.testMenuConnection();
    if (mounted) {
      setState(() {
        _aiTestResult = result;
        _isTestingAi = false;
      });
    }
  }

  Future<void> _testOneDay() async {
    final profile = _profile;
    if (profile == null ||
        !profile.hasProfileDetails ||
        profile.country.trim().isEmpty ||
        _isGenerating ||
        _isTestingAi ||
        _isTestingDay ||
        _isTestingMeal) {
      return;
    }
    setState(() {
      _isTestingDay = true;
      _aiTestResult = null;
      _testDay = null;
      _testMeal = null;
      _dayTestStage = 'Preparando solicitud';
    });
    final watch = Stopwatch()..start();
    try {
      final day = await NutritionAiService.testFullMenuDay(
        profile,
        onStage: (stage) {
          if (mounted) setState(() => _dayTestStage = stage);
        },
      );
      if (mounted) {
        setState(() {
          _testDay = day;
          _aiTestResult =
              'Día de prueba generado en ${watch.elapsed.inSeconds} segundos. No se ha guardado ni cambiado tu menú.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _aiTestResult =
              'La prueba de un día falló después de ${watch.elapsed.inSeconds} segundos. '
              'Etapa: $_dayTestStage. ${NutritionAiService.menuDiagnosticFor(error)} '
              'El menú guardado no se modificó.',
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingDay = false);
    }
  }

  Future<void> _testOneMeal() async {
    final profile = _profile;
    if (profile == null ||
        !profile.hasProfileDetails ||
        profile.country.trim().isEmpty ||
        _isGenerating ||
        _isTestingAi ||
        _isTestingDay ||
        _isTestingMeal) {
      return;
    }
    setState(() {
      _isTestingMeal = true;
      _aiTestResult = null;
      _testDay = null;
      _testMeal = null;
    });
    final watch = Stopwatch()..start();
    try {
      final meal = await NutritionAiService.testDetailedMeal(profile);
      if (mounted) {
        setState(() {
          _testMeal = meal;
          _aiTestResult =
              'Comida de prueba generada en ${watch.elapsed.inSeconds} segundos. No se guardó ni se cambió tu menú.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _aiTestResult =
              'La prueba de una comida falló después de ${watch.elapsed.inSeconds} segundos: ${NutritionAiService.menuMessageFor(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingMeal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Generar menú'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
          ? _GeneratorError(message: _error ?? 'Completa primero tu perfil.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                const Text(
                  'Tu menú',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usaremos los datos guardados en tu perfil para crear recetas y porciones adecuadas para ti.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 18),
                _ProfileSummary(profile: _profile!),
                const SizedBox(height: 18),
                _GeneratorActions(
                  isGenerating:
                      _isGenerating ||
                      _isTestingAi ||
                      _isTestingDay ||
                      _isTestingMeal,
                  hasExistingMenu: _weeklyMenu != null,
                  canCreateManual:
                      _profile!.hasProfileDetails &&
                      _profile!.country.trim().isNotEmpty,
                  canGenerateAi:
                      _profile!.hasProfileDetails &&
                      _profile!.country.trim().isNotEmpty &&
                      !_isAiCoolingDown,
                  onAi: () => _createMenu(withAi: true),
                  onManual: () => _createMenu(withAi: false),
                ),
                TextButton.icon(
                  onPressed:
                      _isGenerating ||
                          _isTestingAi ||
                          _isTestingDay ||
                          _isTestingMeal
                      ? null
                      : _testAi,
                  icon: _isTestingAi
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: Text(
                    _isTestingAi
                        ? 'Probando conexión...'
                        : 'Probar conexión con Gemini',
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _isGenerating ||
                          _isTestingAi ||
                          _isTestingDay ||
                          _isTestingMeal ||
                          !_profile!.hasProfileDetails ||
                          _profile!.country.trim().isEmpty
                      ? null
                      : _testOneDay,
                  icon: _isTestingDay
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.science_outlined),
                  label: Text(
                    _isTestingDay
                        ? 'Probando: $_dayTestStage...'
                        : 'Probar un día en 4 solicitudes',
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _isGenerating ||
                          _isTestingAi ||
                          _isTestingDay ||
                          _isTestingMeal ||
                          !_profile!.hasProfileDetails ||
                          _profile!.country.trim().isEmpty
                      ? null
                      : _testOneMeal,
                  icon: _isTestingMeal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restaurant_menu_outlined),
                  label: Text(
                    _isTestingMeal
                        ? 'Probando una comida...'
                        : 'Probar una comida detallada',
                  ),
                ),
                if (_aiTestResult != null)
                  Text(_aiTestResult!, style: const TextStyle(height: 1.4)),
                if (_testMeal != null) ...[
                  const SizedBox(height: 8),
                  Text('${_testMeal!.type}: ${_testMeal!.name}'),
                  Text(
                    '${_testMeal!.ingredients.length} ingredientes · ${_testMeal!.steps.length} pasos · ${_testMeal!.calories} kcal aproximadas',
                  ),
                ],
                if (_testDay != null) ...[
                  const SizedBox(height: 8),
                  ..._testDay!.meals.map(
                    (meal) => ExpansionTile(
                      title: Text('${meal.type}: ${meal.name}'),
                      subtitle: Text(
                        '${meal.calories} kcal aproximadas · ${meal.prepMinutes} min',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Ingredientes'),
                        ),
                        ...meal.ingredients.map(
                          (ingredient) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '• ${ingredient.amount} ${ingredient.name}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Preparación'),
                        ),
                        ...meal.steps.asMap().entries.map(
                          (entry) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text('${entry.key + 1}. ${entry.value}'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Precauciones: ${meal.allergensAndPrecautions}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isGenerating) ...[
                  const SizedBox(height: 28),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('Creando las propuestas de tu menú de hoy...'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  _GeneratorError(message: _error!),
                ],
                if (_weeklyMenu != null) ...[
                  const SizedBox(height: 26),
                  _WeeklyMenuResult(weeklyMenu: _weeklyMenu!),
                ],
              ],
            ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile});
  final UserNutritionProfile profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.hasProfileDetails || profile.country.trim().isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Completa edad, estatura, peso y país desde tu perfil antes de crear un menú.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos que usará el menú',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            '${profile.age} años · ${profile.weightKg.round()} kg · ${profile.heightCm.round()} cm',
          ),
          const SizedBox(height: 3),
          Text('Actividad: ${profile.activityLevel}'),
          Text('País: ${profile.country}'),
          Text('Objetivo: ${profile.goal}'),
          Text(
            'Restricciones: ${profile.restrictions.isEmpty ? 'Ninguna' : profile.restrictions.join(', ')}',
          ),
          if (profile.healthNotes.trim().isNotEmpty)
            Text('Salud: ${profile.healthNotes}'),
        ],
      ),
    );
  }
}

class _GeneratorActions extends StatelessWidget {
  const _GeneratorActions({
    required this.isGenerating,
    required this.hasExistingMenu,
    required this.canGenerateAi,
    required this.canCreateManual,
    required this.onAi,
    required this.onManual,
  });
  final bool isGenerating;
  final bool hasExistingMenu;
  final bool canGenerateAi;
  final bool canCreateManual;
  final VoidCallback onAi;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: isGenerating || !canGenerateAi ? null : onAi,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(
            hasExistingMenu
                ? 'Regenerar menú de hoy con IA'
                : 'Generar menú de hoy con IA',
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: isGenerating || !canCreateManual ? null : onManual,
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Crear guía manual'),
        ),
      ),
    ],
  );
}

class _WeeklyMenuResult extends StatelessWidget {
  const _WeeklyMenuResult({required this.weeklyMenu});
  final WeeklyMenu weeklyMenu;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Menú guardado',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        weeklyMenu.source == 'ai_daily'
            ? 'Creado con IA según tu perfil. Abre las comidas desde el inicio para consultar sus detalles.'
            : weeklyMenu.source == 'ai'
            ? 'Creado con IA según tu perfil.'
            : 'Guía inicial editable creada.',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      ...weeklyMenu.days.map(
        (day) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(
              day.day,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              weeklyMenu.source == 'ai_daily' &&
                      day.meals.any((meal) => meal.ingredients.isEmpty)
                  ? 'Información nutricional pendiente'
                  : '${day.totalCalories} kcal · ${day.totalProtein.round()} g proteína',
            ),
            children: day.meals
                .map(
                  (meal) => ListTile(
                    title: Text('${meal.type}: ${meal.name}'),
                    subtitle: Text(
                      meal.ingredients.isEmpty
                          ? 'Detalles pendientes'
                          : '${meal.calories} kcal · ${meal.proteinGrams.round()} P · ${meal.carbsGrams.round()} C · ${meal.fatGrams.round()} G',
                    ),
                    trailing: meal.prepMinutes > 0
                        ? Text('${meal.prepMinutes} min')
                        : null,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );
}

class _GeneratorError extends StatelessWidget {
  const _GeneratorError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message),
    ),
  );
}
