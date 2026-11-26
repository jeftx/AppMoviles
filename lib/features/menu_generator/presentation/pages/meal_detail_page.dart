import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/navigation/more_menu.dart';
import '../../../../core/navigation/construction_page.dart';
import '../../../../core/navigation/quick_actions_menu.dart';
import 'daily_menu_generator_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class MealDetailPage extends StatelessWidget {
  final MenuMeal meal;
  final String imagePath;
  final Future<void> Function()? onDelete;

  const MealDetailPage({
    super.key,
    required this.meal,
    required this.imagePath,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    bottomNavigationBar: _MealDetailNavigation(
      onHome: () => Navigator.of(context).pop(),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 106),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeader(type: meal.type),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Menú de hoy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMain,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Color(0xFFF8EEF2),
                            child: Icon(
                              Icons.restaurant_outlined,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'MENÚ DE HOY · ${meal.type.toUpperCase()}',
                  style: _MealDetailStyles.eyebrow,
                ),
                const SizedBox(height: 6),
                Text(meal.name, style: _MealDetailStyles.title),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _Metadata(
                      icon: Icons.access_time_rounded,
                      text: '${meal.prepMinutes} min en total',
                    ),
                    _Metadata(
                      icon: Icons.people_outline_rounded,
                      text: _servingText(meal.serving),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            openConstructionPage(context, 'Editar comida'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar comida'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteMeal(context),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Eliminar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB6424A),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _NutritionSection(meal: meal),
                if (meal.vitamins.isNotEmpty ||
                    meal.minerals.isNotEmpty ||
                    meal.nutritionNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _NutrientDetailsSection(meal: meal),
                ],
                const SizedBox(height: 28),
                _IngredientsSection(meal: meal),
                const SizedBox(height: 28),
                _PreparationSection(meal: meal),
                if (meal.allergensAndPrecautions.trim().isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _AllergensSection(meal: meal),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String _servingText(String serving) {
    final normalized = serving.trim();
    if (normalized.isEmpty) return '1 porción';
    return normalized.toLowerCase().contains('porción')
        ? normalized
        : '$normalized porción';
  }

  Future<void> _deleteMeal(BuildContext context) async {
    if (onDelete == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible eliminar esta comida.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta comida?'),
        content: Text('"${meal.name}" dejará de aparecer en el menú de hoy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB6424A),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await onDelete!();
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la comida. Inténtalo de nuevo.'),
          ),
        );
      }
    }
  }
}

class _PageHeader extends StatelessWidget {
  final String type;

  const _PageHeader({required this.type});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.eco_outlined,
          size: 18,
          color: AppColors.primaryDark,
        ),
      ),
      const SizedBox(width: 9),
      Text(type, style: _MealDetailStyles.header),
    ],
  );
}

class _Metadata extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Metadata({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Text(text, style: _MealDetailStyles.metadata),
    ],
  );
}

class _NutritionSection extends StatelessWidget {
  final MenuMeal meal;

  const _NutritionSection({required this.meal});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Información nutricional', style: _MealDetailStyles.sectionTitle),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department_outlined, size: 20),
                    SizedBox(width: 7),
                    Text('Por porción'),
                  ],
                ),
                RichText(
                  text: TextSpan(
                    style: _MealDetailStyles.calories,
                    children: [
                      TextSpan(text: '${meal.calories} '),
                      TextSpan(text: 'kcal', style: _MealDetailStyles.kcal),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Divider(height: 1, color: AppColors.primary),
            ),
            Row(
              children: [
                _Macro(
                  value: _formatGrams(meal.proteinGrams),
                  label: 'Proteína',
                ),
                _Macro(value: _formatGrams(meal.carbsGrams), label: 'Carbos'),
                _Macro(value: _formatGrams(meal.fatGrams), label: 'Grasas'),
              ],
            ),
            if (meal.fiberGrams > 0) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.eco_outlined,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Fibra: ${_formatGrams(meal.fiberGrams)} por porción',
                    style: _MealDetailStyles.fiber,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );

  String _formatGrams(double grams) => '${grams.round()} g';
}

class _NutrientDetailsSection extends StatelessWidget {
  final MenuMeal meal;

  const _NutrientDetailsSection({required this.meal});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Vitaminas y minerales', style: _MealDetailStyles.sectionTitle),
      const SizedBox(height: 3),
      Text(
        'Valores nutricionales aproximados por porción',
        style: _MealDetailStyles.helper,
      ),
      if (meal.vitamins.isNotEmpty) ...[
        const SizedBox(height: 13),
        Text('Vitaminas', style: _MealDetailStyles.subsectionTitle),
        const SizedBox(height: 3),
        _NutrientList(items: meal.vitamins),
      ],
      if (meal.minerals.isNotEmpty) ...[
        const SizedBox(height: 13),
        Text('Minerales', style: _MealDetailStyles.subsectionTitle),
        const SizedBox(height: 3),
        _NutrientList(items: meal.minerals),
      ],
      if (meal.nutritionNotes.trim().isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F0EB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            meal.nutritionNotes,
            style: _MealDetailStyles.nutritionNote,
          ),
        ),
      ],
    ],
  );
}

class _NutrientList extends StatelessWidget {
  final List<NutrientItem> items;

  const _NutrientList({required this.items});

  @override
  Widget build(BuildContext context) => Column(
    children: items
        .map(
          (item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(item.name, style: _MealDetailStyles.listText),
                ),
                const SizedBox(width: 12),
                Text(item.amount, style: _MealDetailStyles.nutrientAmount),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _Macro extends StatelessWidget {
  final String value;
  final String label;

  const _Macro({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: _MealDetailStyles.macroValue),
        const SizedBox(height: 2),
        Text(label, style: _MealDetailStyles.macroLabel),
      ],
    ),
  );
}

class _IngredientsSection extends StatelessWidget {
  final MenuMeal meal;

  const _IngredientsSection({required this.meal});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Ingredientes', style: _MealDetailStyles.sectionTitle),
          Text(
            'Para ${_servingText(meal.serving)}',
            style: _MealDetailStyles.helper,
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (meal.ingredients.isEmpty)
        Text(
          'No se registraron ingredientes para esta comida.',
          style: _MealDetailStyles.empty,
        )
      else
        ...meal.ingredients.map(
          (ingredient) => Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient.amount.trim().isEmpty
                        ? ingredient.name
                        : '${ingredient.amount} · ${ingredient.name}',
                    style: _MealDetailStyles.listText,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  String _servingText(String serving) =>
      serving.trim().isEmpty ? '1 porción' : serving;
}

class _PreparationSection extends StatelessWidget {
  final MenuMeal meal;

  const _PreparationSection({required this.meal});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Preparación', style: _MealDetailStyles.sectionTitle),
      const SizedBox(height: 14),
      if (meal.steps.isEmpty)
        Text(
          'No se registraron pasos para esta comida.',
          style: _MealDetailStyles.empty,
        )
      else
        ...List.generate(
          meal.steps.length,
          (index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == meal.steps.length - 1 ? 0 : 16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7EAF0),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: _MealDetailStyles.stepNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      meal.steps[index],
                      style: _MealDetailStyles.stepText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _AllergensSection extends StatelessWidget {
  final MenuMeal meal;

  const _AllergensSection({required this.meal});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 18),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alérgenos y precauciones',
          style: _MealDetailStyles.allergenTitle,
        ),
        const SizedBox(height: 7),
        Text(
          meal.allergensAndPrecautions,
          style: _MealDetailStyles.allergenText,
        ),
        const SizedBox(height: 8),
        Text(
          'Las cantidades y nutrientes son estimaciones. Si tienes una condición médica o una dieta indicada, consulta a un profesional antes de modificar tu alimentación.',
          style: _MealDetailStyles.disclaimer,
        ),
      ],
    ),
  );
}

class _MealDetailNavigation extends StatelessWidget {
  final VoidCallback onHome;

  const _MealDetailNavigation({required this.onHome});

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        _NavItem(
          icon: Icons.menu_rounded,
          label: 'Más',
          onTap: () => showMoreMenu(
            context,
            onProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ),
        _NavItem(icon: Icons.home_outlined, label: 'Inicio', onTap: onHome),
        const Expanded(child: Center(child: QuickActionsButton())),
        _NavItem(
          icon: Icons.auto_awesome_outlined,
          label: 'Generar',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const DailyMenuGeneratorPage(),
            ),
          ),
        ),
        _NavItem(
          icon: Icons.smart_toy_outlined,
          label: 'Asistente',
          onTap: () => openConstructionPage(context, 'Asistente'),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _NavItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(height: 2),
          Text(label, style: _MealDetailStyles.nav),
        ],
      ),
    ),
  );
}

abstract class _MealDetailStyles {
  static final header = GoogleFonts.quicksand(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final eyebrow = GoogleFonts.nunito(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.textSecondary,
    letterSpacing: .45,
  );

  static final title = GoogleFonts.quicksand(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final metadata = GoogleFonts.nunito(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static final sectionTitle = GoogleFonts.quicksand(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final calories = GoogleFonts.quicksand(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final kcal = GoogleFonts.nunito(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMain,
  );

  static final macroValue = GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.textMain,
  );

  static final macroLabel = GoogleFonts.nunito(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static final fiber = GoogleFonts.nunito(
    fontSize: 14,
    color: AppColors.textMain,
  );
  static final helper = GoogleFonts.nunito(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static final listText = GoogleFonts.nunito(
    fontSize: 14,
    color: AppColors.textMain,
  );
  static final subsectionTitle = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );
  static final nutrientAmount = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );
  static final nutritionNote = GoogleFonts.nunito(
    fontSize: 13,
    height: 1.35,
    color: AppColors.textSecondary,
  );
  static final empty = GoogleFonts.nunito(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
  static final stepNumber = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w800,
  );
  static final stepText = GoogleFonts.nunito(
    fontSize: 14,
    height: 1.45,
    color: AppColors.textMain,
  );
  static final allergenTitle = GoogleFonts.quicksand(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );
  static final allergenText = GoogleFonts.nunito(
    fontSize: 14,
    height: 1.4,
    color: AppColors.textSecondary,
  );
  static final disclaimer = GoogleFonts.nunito(
    fontSize: 12,
    height: 1.35,
    color: AppColors.textSecondary,
  );
  static final nav = GoogleFonts.nunito(
    fontSize: 11,
    color: AppColors.textSecondary,
  );
}
