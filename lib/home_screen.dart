import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/profile/presentation/widgets/profile_avatar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileName = _profileName(user);
    final greetingName = profileName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const _BottomNavigation(),
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
                const _NutritionSummary(),
                const SizedBox(height: 18),
                const _QuickActions(),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Menú de hoy', style: _Styles.sectionTitle),
                    TextButton(
                      onPressed: () {},
                      child: Text('Cambiar', style: _Styles.link),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _MealList(),
                const SizedBox(height: 18),
                const _AiTip(),
                const SizedBox(height: 16),
                const _WaterProgress(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _profileName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Usuario';
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
              child: const Icon(Icons.eco_outlined, color: AppColors.primaryDark),
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
  const _NutritionSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _Styles.cardDecoration,
      child: Row(
        children: [
          const _CaloriesRing(),
          const SizedBox(width: 22),
          const Expanded(
            child: Column(
              children: [
                _MacroProgress(
                  label: 'Proteína',
                  value: '72/110 g',
                  progress: .65,
                  color: Color(0xFFECA7C5),
                ),
                SizedBox(height: 16),
                _MacroProgress(
                  label: 'Carbos',
                  value: '140/210 g',
                  progress: .67,
                  color: Color(0xFFA7D7BC),
                ),
                SizedBox(height: 16),
                _MacroProgress(
                  label: 'Grasas',
                  value: '40/63 g',
                  progress: .63,
                  color: Color(0xFFD8C6EF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesRing extends StatelessWidget {
  const _CaloriesRing();

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
              value: 1150 / 1900,
              strokeWidth: 9,
              backgroundColor: const Color(0xFFF4ECEF),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1150', style: _Styles.calories),
              Text('de 1900 kcal', style: _Styles.smallText),
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
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _ActionCard(
            title: 'Generar menú',
            subtitle: 'Aleatorio o a tu medida',
            icon: Icons.auto_awesome_outlined,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _ActionCard(
            title: 'Escanear comida',
            subtitle: 'Calorías con IA',
            icon: Icons.document_scanner_outlined,
            color: Color(0xFFD3E9D9),
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

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {},
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

class _MealList extends StatelessWidget {
  const _MealList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MealCard(
          icon: Icons.breakfast_dining_outlined,
          meal: 'Desayuno',
          description: 'Avena con frutos rojos y chía',
          calories: '380 kcal',
        ),
        SizedBox(height: 10),
        _MealCard(
          icon: Icons.lunch_dining_outlined,
          meal: 'Almuerzo',
          description: 'Bowl de quinoa, pollo y aguacate',
          calories: '560 kcal',
        ),
        SizedBox(height: 10),
        _MealCard(
          icon: Icons.icecream_outlined,
          meal: 'Snack',
          description: 'Yogur griego con nueces',
          calories: '210 kcal',
        ),
        SizedBox(height: 10),
        _MealCard(
          icon: Icons.dinner_dining_outlined,
          meal: 'Cena',
          description: 'Salmón al horno con verduras',
          calories: '490 kcal',
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final IconData icon;
  final String meal;
  final String description;
  final String calories;

  const _MealCard({
    required this.icon,
    required this.meal,
    required this.description,
    required this.calories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _Styles.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8EEF2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal, style: _Styles.mealTitle),
                const SizedBox(height: 3),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _Styles.mealDescription,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(calories, style: _Styles.calorieTag),
        ],
      ),
    );
  }
}

class _AiTip extends StatelessWidget {
  const _AiTip();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5EEF9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.smart_toy_outlined, color: Color(0xFF7A5D90)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Te faltan aproximadamente 38 g de proteína hoy. Prueba un snack con yogur griego.',
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

class _WaterProgress extends StatelessWidget {
  const _WaterProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [AppTheme.globalShadow],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.water_drop_outlined,
            color: Color(0xFF2C4A3E),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text('Agua', style: _Styles.mealTitle),
          const Spacer(),
          Row(
            children: List.generate(
              8,
              (index) => Container(
                width: 11,
                height: 24,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: index < 5
                      ? const Color(0xFFC8E1D0)
                      : const Color(0xFFF5F0ED),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
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
            children: const [
              _NavigationItem(icon: Icons.menu_rounded, label: 'Más'),
              _NavigationItem(icon: Icons.home_outlined, label: 'Inicio'),
              _AddNavigationButton(),
              _NavigationItem(icon: Icons.auto_awesome_outlined, label: 'Generar'),
              _NavigationItem(icon: Icons.smart_toy_outlined, label: 'Asistente'),
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

  const _NavigationItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textSecondary;
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 3),
          Text(label, style: _Styles.navigation.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _AddNavigationButton extends StatelessWidget {
  const _AddNavigationButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 54,
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: AppColors.primaryDark, size: 29),
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
    color: AppColors.primaryDark.withOpacity(.72),
  );

  static final mealTitle = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final mealDescription = GoogleFonts.nunito(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static final calorieTag = GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDark,
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
