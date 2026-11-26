import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/ai/nutrition_ai_service.dart';
import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/nutrition/water_goal.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../home_screen.dart';
import '../../../profile/data/nutrition_profile_repository.dart';

/// Personalización inicial guardada en `users/{uid}`.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.initialProfile,
    this.returnToPrevious = false,
  });

  final UserNutritionProfile? initialProfile;
  final bool returnToPrevious;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _aboutScrollController = ScrollController();
  final _foodScrollController = ScrollController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _countryController = TextEditingController();
  final _healthNotesController = TextEditingController();
  final _ageFocusNode = FocusNode();
  final _heightFocusNode = FocusNode();
  final _weightFocusNode = FocusNode();
  final _healthFocusNode = FocusNode();
  final _repository = NutritionProfileRepository();
  final Set<String> _restrictions = {};

  static const _stepCount = 3;
  int _step = 0;
  String _sex = 'Prefiero no decirlo';
  String _activity = 'Moderada';
  String _goal = 'Mantener peso';
  bool _usesAiMenu = true;
  bool _skippedMenuChoice = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null && profile.hasProfileDetails) {
      _ageController.text = profile.age.toString();
      _heightController.text = profile.heightCm.round().toString();
      _weightController.text = profile.weightKg.round().toString();
      _countryController.text = profile.country;
      _healthNotesController.text = profile.healthNotes;
      _restrictions.addAll(profile.restrictions);
      _sex = profile.sex;
      _activity = profile.activityLevel;
      _goal = profile.goal;
      _usesAiMenu = profile.usesAiMenu;
    }
    _ageFocusNode.addListener(() => _scrollAboutForKeyboard(_ageFocusNode));
    _heightFocusNode.addListener(
      () => _scrollAboutForKeyboard(_heightFocusNode),
    );
    _weightFocusNode.addListener(
      () => _scrollAboutForKeyboard(_weightFocusNode),
    );
    _healthFocusNode.addListener(_scrollFoodForKeyboard);
  }

  @override
  void dispose() {
    _aboutScrollController.dispose();
    _foodScrollController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _countryController.dispose();
    _healthNotesController.dispose();
    _ageFocusNode.dispose();
    _heightFocusNode.dispose();
    _weightFocusNode.dispose();
    _healthFocusNode.dispose();
    super.dispose();
  }

  void _scrollAboutForKeyboard(FocusNode node) {
    if (!node.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || !_aboutScrollController.hasClients) return;
      final target = (_aboutScrollController.offset + 180).clamp(
        0.0,
        _aboutScrollController.position.maxScrollExtent,
      );
      _aboutScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollFoodForKeyboard() {
    if (!_healthFocusNode.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted || !_foodScrollController.hasClients) return;
      _foodScrollController.animateTo(
        _foodScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _next() async {
    if (_step == _stepCount - 1) return _finish();
    if (!_validCurrentStep()) return;
    _goTo(_step + 1);
  }

  Future<void> _skip() async {
    setState(() => _error = null);
    if (_step == _stepCount - 1) {
      setState(() => _skippedMenuChoice = true);
      return _finish();
    }
    _goTo(_step + 1);
  }

  void _goTo(int page) => setState(() {
    _step = page.clamp(0, _stepCount - 1).toInt();
    if (_step == _stepCount - 1 && !_hasEssentialData) {
      _usesAiMenu = false;
    }
    _error = null;
  });

  bool _validCurrentStep() {
    if (_step != 0) return true;
    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final valid =
        age != null &&
        age >= 13 &&
        age <= 120 &&
        height != null &&
        height >= 80 &&
        height <= 250 &&
        weight != null &&
        weight >= 20 &&
        weight <= 400;
    if (!valid) {
      setState(() => _error = 'Completa tus datos para continuar.');
    }
    return valid;
  }

  bool get _hasBodyData =>
      int.tryParse(_ageController.text.trim()) != null &&
      double.tryParse(_heightController.text.trim()) != null &&
      double.tryParse(_weightController.text.trim()) != null;

  bool get _hasEssentialData =>
      _hasBodyData && _countryController.text.trim().isNotEmpty;

  Future<void> _finish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final profile = _buildProfile(user);
    final canGenerateAi = _usesAiMenu && _hasEssentialData;
    WeeklyMenuDay? dailyMenu;
    final date = NutritionProfileRepository.dateKey(DateTime.now());
    if (!_skippedMenuChoice && _hasEssentialData && canGenerateAi) {
      try {
        final existingMenu = await _repository
            .watchDailyMenu(user.uid, date)
            .first;
        if (existingMenu == null) {
          dailyMenu = await NutritionAiService.generateDailyOutline(profile);
          if (date != NutritionProfileRepository.dateKey(DateTime.now())) {
            throw StateError(
              'La fecha cambió durante la generación. Vuelve a intentarlo.',
            );
          }
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _isSaving = false;
            _error =
                'No pudimos generar un menú completo y variado. '
                '${NutritionAiService.menuMessageFor(error)}';
          });
        }
        return;
      }
    }

    final completedProfile = UserNutritionProfile(
      name: profile.name,
      age: profile.age,
      sex: profile.sex,
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      activityLevel: profile.activityLevel,
      country: profile.country,
      restrictions: profile.restrictions,
      healthNotes: profile.healthNotes,
      goal: profile.goal,
      dailyCalorieGoal: profile.dailyCalorieGoal,
      dailyWaterGoalMl: profile.dailyWaterGoalMl,
      usesAiMenu: canGenerateAi,
      hasProfileDetails: profile.hasProfileDetails,
      hasWeeklyMenu: false,
    );

    try {
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw StateError('La sesión cambió durante la generación.');
      }
      await _repository.save(user.uid, completedProfile, email: user.email);
      if (dailyMenu != null) {
        try {
          await _repository.saveDailyMenu(user.uid, date, dailyMenu);
        } on DailyMenuAlreadyExistsException {
          // Otra sesión guardó un menú para hoy; se conserva el existente.
        }
      }
      if (!mounted) return;
      if (widget.returnToPrevious) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos guardar tu perfil. Revisa Firestore e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  UserNutritionProfile _buildProfile(User user) {
    final age = int.tryParse(_ageController.text.trim()) ?? 25;
    final height = double.tryParse(_heightController.text.trim()) ?? 165;
    final weight = double.tryParse(_weightController.text.trim()) ?? 65;
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? 'Usuario';
    return UserNutritionProfile(
      name: name,
      age: age,
      sex: _sex,
      weightKg: weight,
      heightCm: height,
      activityLevel: _activity,
      country: _countryController.text.trim(),
      restrictions: _restrictions.toList()..sort(),
      healthNotes: _healthNotesController.text.trim(),
      goal: _goal,
      dailyCalorieGoal: _calculateCalories(age, height, weight),
      dailyWaterGoalMl: _hasBodyData ? dailyWaterGoalMl(weight) : 0,
      usesAiMenu: _usesAiMenu,
      hasProfileDetails: _hasBodyData,
      hasWeeklyMenu: false,
    );
  }

  int _calculateCalories(int age, double height, double weight) {
    final bmr = switch (_sex) {
      'Hombre' => 10 * weight + 6.25 * height - 5 * age + 5,
      'Mujer' => 10 * weight + 6.25 * height - 5 * age - 161,
      _ => 10 * weight + 6.25 * height - 5 * age - 78,
    };
    final factor = switch (_activity) {
      'Sedentaria' => 1.2,
      'Ligera' => 1.375,
      'Moderada' => 1.55,
      'Alta' => 1.725,
      _ => 1.55,
    };
    final adjustment = switch (_goal) {
      'Bajar de peso' => -350,
      'Ganar masa muscular' => 300,
      _ => 0,
    };
    return (bmr * factor + adjustment).round().clamp(1200, 4000);
  }

  @override
  Widget build(BuildContext context) {
    final lastStep = _step == _stepCount - 1;
    final stepContent = switch (_step) {
      0 => _AboutYouStep(
        ageController: _ageController,
        heightController: _heightController,
        weightController: _weightController,
        scrollController: _aboutScrollController,
        ageFocusNode: _ageFocusNode,
        heightFocusNode: _heightFocusNode,
        weightFocusNode: _weightFocusNode,
      ),
      1 => _FoodStep(
        goal: _goal,
        activity: _activity,
        sex: _sex,
        restrictions: _restrictions,
        country: _countryController.text,
        onCountryChanged: (value) => setState(() {
          _countryController.text = value;
        }),
        healthNotesController: _healthNotesController,
        scrollController: _foodScrollController,
        healthFocusNode: _healthFocusNode,
        onGoalChanged: (value) => setState(() => _goal = value),
        onActivityChanged: (value) => setState(() => _activity = value),
        onSexChanged: (value) => setState(() => _sex = value),
        onRestrictionChanged: (item, selected) => setState(() {
          selected ? _restrictions.add(item) : _restrictions.remove(item);
        }),
      ),
      _ => _MenusStep(
        usesAiMenu: _usesAiMenu,
        canUseAi: _hasEssentialData,
        onChanged: (value) => setState(() {
          _usesAiMenu = value;
          _skippedMenuChoice = false;
        }),
      ),
    };
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            children: [
              _OnboardingHeader(step: _step),
              if (_step > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : () => _goTo(_step - 1),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Volver'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.025, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_step), child: stepContent),
                ),
              ),
              if (_error != null) ...[
                _OnboardingError(message: _error!),
                const SizedBox(height: 10),
              ],
              if (_isSaving && _usesAiMenu && _hasEssentialData)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Creando las propuestas de tu menú de hoy...'),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _isSaving ? null : _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          lastStep
                              ? (!_hasEssentialData
                                    ? 'Continuar sin menú'
                                    : _usesAiMenu
                                    ? 'Empezar con IA'
                                    : 'Continuar')
                              : 'Continuar',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              TextButton(
                onPressed: _isSaving ? null : _skip,
                child: Text(
                  lastStep ? 'Omitir por ahora' : 'Omitir',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: AppColors.primaryDark,
              size: 17,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'NutriMenu AI',
            style: GoogleFonts.quicksand(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const Spacer(),
          Text(
            'Paso ${step + 1} de 3',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      Row(
        children: List.generate(
          _OnboardingPageState._stepCount,
          (index) => Expanded(
            child: Container(
              height: 5,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 7),
              decoration: BoxDecoration(
                color: index <= step
                    ? AppColors.primary
                    : const Color(0xFFF0E8EB),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              'Sobre ti',
              style: step == 0 ? _TabLabel.active : _TabLabel.inactive,
            ),
          ),
          Expanded(
            child: Text(
              'Tu alimentación',
              textAlign: TextAlign.center,
              style: step == 1 ? _TabLabel.active : _TabLabel.inactive,
            ),
          ),
          Expanded(
            child: Text(
              'Tus menús',
              textAlign: TextAlign.right,
              style: step == 2 ? _TabLabel.active : _TabLabel.inactive,
            ),
          ),
        ],
      ),
    ],
  );
}

class _OnboardingError extends StatelessWidget {
  const _OnboardingError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDEF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF3C8CF)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFFB45362),
          size: 19,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xFF80414A),
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ),
      ],
    ),
  );
}

abstract class _TabLabel {
  static const active = TextStyle(
    color: AppColors.textMain,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
  static const inactive = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
  );
}

class _AboutYouStep extends StatelessWidget {
  const _AboutYouStep({
    required this.ageController,
    required this.heightController,
    required this.weightController,
    required this.scrollController,
    required this.ageFocusNode,
    required this.heightFocusNode,
    required this.weightFocusNode,
  });
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final ScrollController scrollController;
  final FocusNode ageFocusNode;
  final FocusNode heightFocusNode;
  final FocusNode weightFocusNode;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: scrollController,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/images/onboarding_food.jpg',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'UN COMIENZO A TU MEDIDA',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vamos a conocerte\nun poquito mejor',
          style: GoogleFonts.quicksand(
            fontSize: 27,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Cada cuerpo es diferente. Empecemos con tus datos para personalizar tus menús.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 25),
        _CompactNumberField(
          controller: ageController,
          label: 'Edad',
          unit: 'años',
          icon: Icons.cake_outlined,
          focusNode: ageFocusNode,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CompactNumberField(
                controller: heightController,
                label: 'Estatura',
                unit: 'cm',
                icon: Icons.straighten_outlined,
                focusNode: heightFocusNode,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _CompactNumberField(
                controller: weightController,
                label: 'Peso',
                unit: 'kg',
                icon: Icons.monitor_weight_outlined,
                focusNode: weightFocusNode,
              ),
            ),
          ],
        ),
        // Margen desplazable para que el teclado no quede junto a los campos.
        const SizedBox(height: 60),
      ],
    ),
  );
}

class _CompactNumberField extends StatelessWidget {
  const _CompactNumberField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.icon,
    required this.focusNode,
  });
  final TextEditingController controller;
  final String label;
  final String unit;
  final IconData icon;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: '—',
          suffixText: unit,
          suffixStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    ],
  );
}

class _FoodStep extends StatelessWidget {
  const _FoodStep({
    required this.goal,
    required this.activity,
    required this.sex,
    required this.restrictions,
    required this.country,
    required this.onCountryChanged,
    required this.healthNotesController,
    required this.scrollController,
    required this.healthFocusNode,
    required this.onGoalChanged,
    required this.onActivityChanged,
    required this.onSexChanged,
    required this.onRestrictionChanged,
  });
  final String goal;
  final String activity;
  final String sex;
  final Set<String> restrictions;
  final String country;
  final ValueChanged<String> onCountryChanged;
  final TextEditingController healthNotesController;
  final ScrollController scrollController;
  final FocusNode healthFocusNode;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<String> onActivityChanged;
  final ValueChanged<String> onSexChanged;
  final void Function(String, bool) onRestrictionChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: scrollController,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'TU ALIMENTACIÓN',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lo que necesitas\npara sentirte bien',
          style: GoogleFonts.quicksand(
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Cuéntanos tus hábitos y preferencias. Podrás cambiarlos cuando quieras.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 22),
        const _SectionLabel('País o región'),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          key: ValueKey(country),
          initialValue: country.trim().isEmpty ? null : country,
          isExpanded: true,
          hint: const Text('Selecciona tu país'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.public_outlined),
          ),
          items:
              const [
                    'Colombia',
                    'México',
                    'Perú',
                    'Ecuador',
                    'Venezuela',
                    'Argentina',
                    'Chile',
                    'Bolivia',
                    'Paraguay',
                    'Uruguay',
                    'Brasil',
                    'España',
                    'Estados Unidos',
                    'Otro país',
                  ]
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) onCountryChanged(value);
          },
        ),
        const SizedBox(height: 19),
        const _SectionLabel('Nivel de actividad'),
        const SizedBox(height: 9),
        _ChoiceChips(
          value: activity,
          options: const ['Sedentaria', 'Ligera', 'Moderada', 'Alta'],
          onChanged: onActivityChanged,
        ),
        const SizedBox(height: 19),
        const _SectionLabel('Sexo (opcional)'),
        const SizedBox(height: 9),
        _ChoiceChips(
          value: sex,
          options: const ['Mujer', 'Hombre', 'Prefiero no decirlo'],
          onChanged: onSexChanged,
        ),
        const SizedBox(height: 19),
        const _SectionLabel('Restricciones o preferencias'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Ninguna',
                    'Sin lactosa',
                    'Sin gluten',
                    'Vegetariana',
                    'Vegana',
                    'Diabetes',
                    'Alergia a frutos secos',
                  ]
                  .map(
                    (item) => _RestrictionChip(
                      label: item,
                      selected: item == 'Ninguna'
                          ? restrictions.isEmpty
                          : restrictions.contains(item),
                      onSelected: (selected) {
                        if (item == 'Ninguna') {
                          for (final restriction in List<String>.from(
                            restrictions,
                          )) {
                            onRestrictionChanged(restriction, false);
                          }
                        } else {
                          onRestrictionChanged(item, selected);
                        }
                      },
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 21),
        const _SectionLabel('¿Cuál es tu objetivo?'),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: goal,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: const TextStyle(color: AppColors.textMain, fontSize: 15),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          items: const ['Bajar de peso', 'Mantener peso', 'Ganar masa muscular']
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value != null) onGoalChanged(value);
          },
        ),
        const SizedBox(height: 21),
        const _SectionLabel('Salud y otras restricciones'),
        const SizedBox(height: 9),
        TextField(
          controller: healthNotesController,
          focusNode: healthFocusNode,
          minLines: 4,
          maxLines: 5,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
          decoration: const InputDecoration(
            hintText: 'Ej. hipertensión, dieta indicada, alergias u otra información relevante',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        const _HealthNotice(),
        const SizedBox(height: 36),
      ],
    ),
  );
}

class _HealthNotice extends StatelessWidget {
  const _HealthNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 12),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
    ),
    child: const Text(
      'Si tienes una enfermedad o una dieta indicada, consulta a un profesional. Las recomendaciones no sustituyen el asesoramiento médico.',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.4,
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMain,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _ChoiceChips extends StatelessWidget {
  const _ChoiceChips({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((option) {
      final selected = value == option;
      return ChoiceChip(
        label: Text(option),
        selected: selected,
        showCheckmark: false,
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (selected) return const Color(0xFFDDF0E4);
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed)) {
            return const Color(0xFFDDEEFF);
          }
          return AppColors.surface;
        }),
        side: const BorderSide(color: AppColors.border),
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => onChanged(option),
      );
    }).toList(),
  );
}

class _RestrictionChip extends StatelessWidget {
  const _RestrictionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    color: WidgetStateProperty.resolveWith<Color?>((states) {
      if (selected) return const Color(0xFFDDF0E4);
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed)) {
        return const Color(0xFFDDEEFF);
      }
      return AppColors.surface;
    }),
    side: const BorderSide(color: AppColors.border),
    labelStyle: TextStyle(
      color: selected ? AppColors.primaryDark : AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    onSelected: onSelected,
  );
}

class _MenusStep extends StatelessWidget {
  const _MenusStep({
    required this.usesAiMenu,
    required this.canUseAi,
    required this.onChanged,
  });
  final bool usesAiMenu;
  final bool canUseAi;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFDDF0E4),
              child: Icon(
                Icons.check_rounded,
                color: Color(0xFF3B7050),
                size: 18,
              ),
            ),
            SizedBox(width: 9),
            Text(
              'Ya tenemos lo esencial',
              style: TextStyle(
                color: Color(0xFF3B7050),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'TUS MENÚS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '¿Cómo te gustaría\nempezar?',
          style: GoogleFonts.quicksand(
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Selecciona cómo quieres empezar con tu menú del día.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 25),
        _MenuChoiceCard(
          selected: usesAiMenu,
          isAi: true,
          enabled: canUseAi,
          icon: Icons.auto_awesome_rounded,
          title: 'Con inteligencia artificial',
          description:
              'Una propuesta diaria inspirada en tus gustos y objetivos.',
          onTap: () => onChanged(true),
        ),
        if (!canUseAi) ...[
          const SizedBox(height: 8),
          const _AiDataRequiredNotice(),
        ],
        const SizedBox(height: 12),
        _MenuChoiceCard(
          selected: !usesAiMenu,
          isAi: false,
          enabled: true,
          icon: Icons.edit_calendar_outlined,
          title: 'Prefiero crearlos yo',
          description: 'La creación manual estará disponible próximamente.',
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: 22),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            'https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=85',
            width: double.infinity,
            height: 128,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 128,
              color: const Color(0xFFEDE3F5),
              child: const Center(
                child: Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Podrás editar tus datos desde tu perfil cuando quieras.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
      ],
    ),
  );
}

class _MenuChoiceCard extends StatelessWidget {
  const _MenuChoiceCard({
    required this.selected,
    required this.isAi,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final bool selected;
  final bool isAi;
  final bool enabled;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? (isAi ? const Color(0xFFEEE3F7) : const Color(0xFFDDF0E4))
        : enabled
        ? AppColors.surface
        : const Color(0xFFF5F1F5),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? (isAi ? const Color(0xFFCDB5DD) : const Color(0xFFA8D3B4))
                : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isAi ? const Color(0xFFE6D6F3) : const Color(0xFFDDF0E4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: enabled
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? AppColors.primaryDark
                  : enabled
                  ? AppColors.textSecondary
                  : const Color(0xFFB8AFB6),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AiDataRequiredNotice extends StatelessWidget {
  const _AiDataRequiredNotice();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.info_outline_rounded,
        color: AppColors.textSecondary,
        size: 17,
      ),
      SizedBox(width: 7),
      Expanded(
        child: Text(
          'Se requieren edad, estatura, peso y país para generar menús con IA.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}
