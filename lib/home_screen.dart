import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/more_menu.dart';
import 'core/navigation/construction_page.dart';
import 'core/navigation/quick_actions_menu.dart';
import 'core/nutrition/water_goal_card.dart';
import 'core/ai/nutrition_models.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/profile/presentation/widgets/profile_avatar.dart';
import 'features/profile/data/nutrition_profile_repository.dart';
import 'features/food_scan/presentation/pages/food_scan_page.dart';
import 'features/menu_generator/presentation/pages/daily_menu_generator_page.dart';
import 'features/menu_generator/presentation/pages/meal_detail_page.dart';
import 'features/menu_generator/presentation/pages/daily_meal_detail_page.dart';
import 'features/menu_generator/presentation/pages/daily_meal_summary_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final profileName = _profileName(user);
    return StreamBuilder<UserNutritionProfile?>(
      key: ValueKey('profile-${user.uid}'),
      stream: NutritionProfileRepository().watch(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('No se pudo cargar tu perfil. Revisa tu conexión.'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const Scaffold(
            body: Center(
              child: Text('No se encontró tu perfil. Vuelve a iniciar sesión.'),
            ),
          );
        }
        final name = profile.name;
        final greetingName = name.split(' ').first;
        final date = NutritionProfileRepository.dateKey(DateTime.now());
        return StreamBuilder<WeeklyMenuDay?>(
          key: ValueKey('daily-${user.uid}-$date'),
          stream: NutritionProfileRepository().watchDailyMenu(user.uid, date),
          builder: (context, dailySnapshot) {
            if (dailySnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'No se pudo cargar el menú de hoy. Revisa tu conexión.',
                  ),
                ),
              );
            }
            if (dailySnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final dailyMenu = dailySnapshot.data;
            final today = dailyMenu;
            final previousMenu = _todayMenuDay(profile);
            final hasTodayMenu = today?.meals.isNotEmpty ?? false;
            final todayIndex = _todayMenuIndex(profile);
            final showProfilePrompt =
                !profile.hasProfileDetails || profile.country.trim().isEmpty;
            void openGenerator() {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DailyMenuGeneratorPage(),
                ),
              );
            }

            return Scaffold(
              backgroundColor: AppColors.background,
              bottomNavigationBar: HomeBottomNavigation(
                onGenerate: openGenerator,
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(name: greetingName, profileName: profileName),
                        const SizedBox(height: 28),
                        if (showProfilePrompt) ...[
                          _ProfilePrompt(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ProfilePage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (dailyMenu != null &&
                            dailyMenu.meals.any((meal) => meal.calories <= 0))
                          const Text('Calorías: ---')
                        else
                          _NutritionSummary(
                            calorieGoal: hasTodayMenu
                                ? profile.dailyCalorieGoal
                                : 0,
                            meals: hasTodayMenu ? today!.meals : const [],
                            macrosPending:
                                dailyMenu != null &&
                                dailyMenu.meals.any(
                                  (meal) =>
                                      meal.ingredients.isEmpty ||
                                      meal.steps.isEmpty,
                                ),
                          ),
                        if (dailyMenu != null &&
                            dailyMenu.meals.every(
                              (meal) => meal.calories > 0,
                            )) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Calorías estimadas del menú; no indican consumo registrado.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _QuickActions(
                          onGenerate: openGenerator,
                          onScan: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FoodScanPage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Menú de hoy', style: _Styles.sectionTitle),
                            TextButton(
                              onPressed: openGenerator,
                              child: Text(
                                hasTodayMenu ? 'Ver menú' : 'Crear',
                                style: _Styles.link,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (dailyMenu?.source == 'default')
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Menú predeterminado orientativo; no está personalizado.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        if (!hasTodayMenu)
                          _EmptyMenu(
                            onCreateAi: openGenerator,
                            onCreateManual: () => openConstructionPage(
                              context,
                              'Crear menú manualmente',
                            ),
                          )
                        else
                          _MealList(
                            meals: today!.meals,
                            onMealTap: (meal, mealIndex) =>
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        meal.ingredients.isEmpty ||
                                            meal.steps.isEmpty
                                        ? DailyMealSummaryPage(
                                            userId: user.uid,
                                            date: date,
                                            meal: meal,
                                            imagePath: _MealList.imageFor(
                                              meal.type,
                                            ),
                                          )
                                        : DailyMealDetailPage(
                                            userId: user.uid,
                                            date: date,
                                            profile: profile,
                                            meal: meal,
                                            imagePath: _MealList.imageFor(
                                              meal.type,
                                            ),
                                          ),
                                  ),
                                ),
                          ),
                        if (previousMenu != null &&
                            previousMenu.meals.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          const Text(
                            'Menú guardado anteriormente',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MealList(
                            meals: previousMenu.meals,
                            onMealTap: (meal, mealIndex) =>
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MealDetailPage(
                                      meal: meal,
                                      imagePath: _MealList.imageFor(meal.type),
                                      onDelete: () =>
                                          NutritionProfileRepository()
                                              .removeMeal(
                                                user.uid,
                                                profile.weeklyMenu!,
                                                dayIndex: todayIndex,
                                                mealIndex: mealIndex,
                                              ),
                                    ),
                                  ),
                                ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _AiTip(profile: profile, menu: dailyMenu),
                        const SizedBox(height: 16),
                        WaterGoalCard(
                          weightKg: profile.hasProfileDetails
                              ? profile.weightKg
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _profileName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Usuario';
  }

  WeeklyMenuDay? _todayMenuDay(UserNutritionProfile profile) {
    return profile.activeLegacyMenuFor(DateTime.now());
  }

  int _todayMenuIndex(UserNutritionProfile profile) {
    final days = profile.weeklyMenu?.days;
    if (days == null || days.isEmpty) return 0;
    return (DateTime.now().weekday - 1) % days.length;
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String profileName;

  const _Header({required this.name, required this.profileName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_outlined,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 10),
            Text('NutriMenu AI', style: _Styles.brand),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Abrir perfil',
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfilePage(),
                    ),
                  ),
                  child: ProfileAvatar(name: profileName, radius: 21),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Hola, $name', style: _Styles.greeting),
      ],
    );
  }
}

class _NutritionSummary extends StatelessWidget {
  final int calorieGoal;
  final List<MenuMeal> meals;
  final bool macrosPending;

  const _NutritionSummary({
    required this.calorieGoal,
    required this.meals,
    this.macrosPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _Styles.cardDecoration,
      child: Row(
        children: [
          _CaloriesRing(
            calorieGoal: calorieGoal,
            calories: meals.fold(0, (sum, meal) => sum + meal.calories),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              children: [
                _MacroProgress(
                  label: 'Proteína',
                  value: macrosPending
                      ? 'Pendiente'
                      : '${_macro(meals, (meal) => meal.proteinGrams).round()}/${(calorieGoal * .25 / 4).round()} g',
                  progress: macrosPending
                      ? 0
                      : _progress(
                          _macro(meals, (meal) => meal.proteinGrams),
                          calorieGoal * .25 / 4,
                        ),
                  color: const Color(0xFFECA7C5),
                ),
                const SizedBox(height: 16),
                _MacroProgress(
                  label: 'Carbos',
                  value: macrosPending
                      ? 'Pendiente'
                      : '${_macro(meals, (meal) => meal.carbsGrams).round()}/${(calorieGoal * .45 / 4).round()} g',
                  progress: macrosPending
                      ? 0
                      : _progress(
                          _macro(meals, (meal) => meal.carbsGrams),
                          calorieGoal * .45 / 4,
                        ),
                  color: const Color(0xFFA7D7BC),
                ),
                const SizedBox(height: 16),
                _MacroProgress(
                  label: 'Grasas',
                  value: macrosPending
                      ? 'Pendiente'
                      : '${_macro(meals, (meal) => meal.fatGrams).round()}/${(calorieGoal * .30 / 9).round()} g',
                  progress: macrosPending
                      ? 0
                      : _progress(
                          _macro(meals, (meal) => meal.fatGrams),
                          calorieGoal * .30 / 9,
                        ),
                  color: const Color(0xFFD8C6EF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _macro(List<MenuMeal> meals, double Function(MenuMeal) pick) =>
      meals.fold(0, (sum, meal) => sum + pick(meal));

  double _progress(double value, double goal) =>
      goal == 0 ? 0 : (value / goal).clamp(0, 1).toDouble();
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFD3E9D9),
    borderRadius: const BorderRadius.all(Radius.circular(24)),
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primaryDark,
              size: 27,
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Un menú que se parezca a ti',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Personalizar mi perfil',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.primaryDark,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CaloriesRing extends StatelessWidget {
  final int calorieGoal;
  final int calories;

  const _CaloriesRing({required this.calorieGoal, required this.calories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: CircularProgressIndicator(
              value: calorieGoal == 0
                  ? 0
                  : (calories / calorieGoal).clamp(0, 1).toDouble(),
              strokeWidth: 9,
              backgroundColor: const Color(0xFFF4ECEF),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$calories', style: _Styles.calories),
              Text('de $calorieGoal kcal', style: _Styles.smallText),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroProgress extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _MacroProgress({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: _Styles.macroLabel),
            const Spacer(),
            Text(value, style: _Styles.macroValue),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFF3EDF0),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback onScan;

  const _QuickActions({required this.onGenerate, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            title: 'Generar menú',
            subtitle: 'Aleatorio o a tu medida',
            icon: Icons.auto_awesome_outlined,
            color: AppColors.primary,
            onTap: onGenerate,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionCard(
            title: 'Escanear comida',
            subtitle: 'Calorías con IA',
            icon: Icons.document_scanner_outlined,
            color: const Color(0xFFD3E9D9),
            onTap: onScan,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 144,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 27),
                const Spacer(),
                Text(title, style: _Styles.actionTitle),
                const SizedBox(height: 3),
                Text(subtitle, style: _Styles.actionSubtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu({required this.onCreateAi, required this.onCreateManual});
  final VoidCallback onCreateAi;
  final VoidCallback onCreateManual;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _Styles.cardDecoration,
    child: Column(
      children: [
        const Icon(
          Icons.menu_book_outlined,
          size: 34,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 10),
        const Text(
          'Aún no tienes menús creados',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(height: 5),
        const Text(
          '¿Deseas crear un menú? Puedes generarlo con IA. La creación manual estará disponible próximamente.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateAi,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Crear menú con IA'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCreateManual,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Crear menú manualmente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textMain,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MealList extends StatelessWidget {
  final List<MenuMeal> meals;
  final void Function(MenuMeal meal, int index) onMealTap;

  const _MealList({required this.meals, required this.onMealTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(meals.length, (index) {
        final meal = meals[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == meals.length - 1 ? 0 : 10),
          child: _MealCard(
            imagePath: imageFor(meal.type),
            meal: meal.type,
            description: meal.name,
            calories: meal.calories,
            onTap: () => onMealTap(meal, index),
          ),
        );
      }),
    );
  }

  static String imageFor(String mealType) {
    final normalizedType = mealType.toLowerCase();
    if (normalizedType.contains('desayuno')) {
      return 'assets/images/meal_breakfast.jpg';
    }
    if (normalizedType.contains('almuerzo')) {
      return 'assets/images/meal_lunch.jpg';
    }
    if (normalizedType.contains('snack') ||
        normalizedType.contains('merienda')) {
      return 'assets/images/meal_snack.jpg';
    }
    return 'assets/images/meal_dinner.jpg';
  }
}

class _MealCard extends StatelessWidget {
  final String imagePath;
  final String meal;
  final String description;
  final int calories;
  final VoidCallback onTap;

  const _MealCard({
    required this.imagePath,
    required this.meal,
    required this.description,
    required this.calories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _Styles.cardDecoration,
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  imagePath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Color(0xFFF8EEF2),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(Icons.restaurant_outlined),
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal, style: _Styles.mealTitle),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _Styles.mealDescription,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    calories > 0 ? '$calories' : '---',
                    style: _Styles.calorieValue,
                  ),
                  Text(calories > 0 ? 'kcal' : '', style: _Styles.calorieUnit),
                ],
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiTip extends StatelessWidget {
  final UserNutritionProfile profile;
  final WeeklyMenuDay? menu;

  const _AiTip({required this.profile, required this.menu});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5EEF9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openConstructionPage(context, 'Asistente'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.smart_toy_outlined, color: Color(0xFF7A5D90)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  menu == null ||
                          menu!.meals.isEmpty ||
                          menu!.meals.any((meal) => meal.calories <= 0)
                      ? 'No existen calorías para calcular.${profile.hasProfileDetails && profile.goal.trim().isNotEmpty ? ' Objetivo: ${profile.goal}.' : ''}'
                      : 'Tu menú suma ${menu!.totalCalories} kcal aproximadas.${profile.hasProfileDetails && profile.dailyCalorieGoal > 0 ? ' Tu meta diaria es ${profile.dailyCalorieGoal} kcal.' : ''}${profile.hasProfileDetails && profile.goal.trim().isNotEmpty ? ' Objetivo: ${profile.goal}.' : ''}',
                  style: _Styles.tip,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF7A5D90)),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeBottomNavigation extends StatelessWidget {
  final VoidCallback onGenerate;
  final VoidCallback? onHome;

  const HomeBottomNavigation({
    super.key,
    required this.onGenerate,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavigationItem(
                icon: Icons.menu_rounded,
                label: 'Más',
                onTap: () => showMoreMenu(
                  context,
                  onProfile: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfilePage(),
                      ),
                    );
                  },
                ),
              ),
              _NavigationItem(
                icon: Icons.home_outlined,
                label: 'Inicio',
                onTap: onHome,
              ),
              const SizedBox(
                width: 62,
                height: 54,
                child: Center(child: QuickActionsButton()),
              ),
              _NavigationItem(
                icon: Icons.auto_awesome_outlined,
                label: 'Generar',
                onTap: onGenerate,
              ),
              _NavigationItem(
                icon: Icons.smart_toy_outlined,
                label: 'Asistente',
                onTap: () => openConstructionPage(context, 'Asistente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavigationItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textSecondary;
    return SizedBox(
      width: 60,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 3),
            Text(label, style: _Styles.navigation.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

abstract class _Styles {
  static final brand = GoogleFonts.quicksand(
    fontWeight: FontWeight.w700,
    fontSize: 20,
    color: AppColors.textMain,
  );

  static final greeting = GoogleFonts.quicksand(
    fontWeight: FontWeight.w700,
    fontSize: 28,
    color: AppColors.textMain,
  );

  static final sectionTitle = GoogleFonts.quicksand(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final link = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDark,
  );

  static final calories = GoogleFonts.quicksand(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final smallText = GoogleFonts.nunito(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  static final macroLabel = GoogleFonts.nunito(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final macroValue = GoogleFonts.nunito(
    fontSize: 13,
    color: AppColors.textSecondary,
  );

  static final actionTitle = GoogleFonts.quicksand(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDark,
  );

  static final actionSubtitle = GoogleFonts.nunito(
    fontSize: 11,
    color: AppColors.primaryDark.withValues(alpha: .72),
  );

  static final mealTitle = GoogleFonts.nunito(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static final mealDescription = GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.15,
    color: AppColors.textMain,
  );

  static final calorieValue = GoogleFonts.nunito(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static final calorieUnit = GoogleFonts.nunito(
    fontSize: 11,
    color: AppColors.textSecondary,
  );

  static final tip = GoogleFonts.nunito(
    fontSize: 13,
    height: 1.4,
    color: AppColors.primaryDark,
  );

  static final navigation = GoogleFonts.nunito(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static final cardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [AppTheme.globalShadow],
  );
}
