import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/ai/nutrition_ai_service.dart';
import '../../../../core/ai/default_daily_menus.dart';
import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/nutrition_profile_repository.dart';

class DailyMenuGeneratorPage extends StatefulWidget {
  const DailyMenuGeneratorPage({super.key});

  @override
  State<DailyMenuGeneratorPage> createState() => _DailyMenuGeneratorPageState();
}

class _DailyMenuGeneratorPageState extends State<DailyMenuGeneratorPage> {
  final _repository = NutritionProfileRepository();
  late final String _date;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = NutritionProfileRepository.dateKey(DateTime.now());
  }

  bool get _isToday =>
      _date == NutritionProfileRepository.dateKey(DateTime.now());

  Future<void> _generate(
    User user,
    UserNutritionProfile profile, {
    WeeklyMenuDay? replacing,
  }) async {
    if (_working) return;
    if (replacing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Regenerar el menú de hoy?'),
          content: const Text(
            'El menú actual se reemplazará solo si la IA genera uno nuevo correctamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Regenerar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (!_isToday) {
        throw StateError('La fecha cambió. Vuelve a abrir esta pantalla.');
      }
      final existing = await _repository.watchDailyMenu(user.uid, _date).first;
      if (replacing == null && existing != null) {
        throw const DailyMenuAlreadyExistsException();
      }
      late final WeeklyMenuDay menu;
      String? aiFailure;
      try {
        menu = await NutritionAiService.generateDailyOutline(profile);
      } catch (error) {
        aiFailure = NutritionAiService.menuMessageFor(error);
        if (replacing != null) {
          if (mounted) {
            setState(
              () => _error =
                  'Falló la IA: $aiFailure\nTu menú actual se conserva.',
            );
          }
          return;
        }
        if (!DefaultDailyMenus.canUse(profile)) {
          if (mounted) {
            setState(
              () => _error =
                  'Falló la IA: $aiFailure\nNo se usó un menú predeterminado porque no podemos verificar que sea adecuado para tus restricciones o condiciones de salud.',
            );
          }
          return;
        }
        menu = DefaultDailyMenus.choose();
      }
      if (!_isToday) {
        throw StateError(
          'La fecha cambió durante la generación. Vuelve a abrir esta pantalla.',
        );
      }
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw StateError('La sesión cambió durante la generación.');
      }
      if (replacing == null) {
        await _repository.saveDailyMenu(user.uid, _date, menu);
      } else {
        await _repository.replaceDailyMenu(user.uid, _date, replacing, menu);
      }
      if (mounted) {
        if (aiFailure != null) {
          setState(
            () => _error =
                'Falló la IA: $aiFailure\nSe guardó un menú predeterminado orientativo; no está personalizado.',
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiFailure == null
                  ? 'Tu menú del día fue guardado.'
                  : 'Se guardó un menú predeterminado.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is DailyMenuAlreadyExistsException
              ? 'Ya tienes un menú guardado para hoy. No fue reemplazado.'
              : NutritionAiService.menuMessageFor(error),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _changeMeal(
    User user,
    WeeklyMenuDay current,
    MenuMeal meal,
  ) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final choices = await _repository.savedMeals(user.uid, _date, meal.type);
      if (meal.type.toLowerCase() == 'desayuno') {
        final original = DefaultDailyMenus.originalBreakfast(current);
        if (original != null &&
            original.name != meal.name &&
            !choices.any(
              (item) => item.id == original.id && item.name == original.name,
            )) {
          choices.insert(0, original);
        }
      }
      if (!mounted) return;
      if (choices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No tienes otras comidas de ${meal.type.toLowerCase()} guardadas.',
            ),
          ),
        );
        return;
      }
      final selected = await showModalBottomSheet<MenuMeal>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Elegir una comida guardada')),
              ...choices.map(
                (choice) => ListTile(
                  title: Text(choice.name),
                  subtitle: Text(choice.description),
                  onTap: () => Navigator.pop(sheetContext, choice),
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      if (!_isToday || FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw StateError('La fecha o la sesión cambió.');
      }
      final meals = current.meals
          .map((item) => identical(item, meal) ? selected : item)
          .toList();
      await _repository.replaceDailyMenu(
        user.uid,
        _date,
        current,
        WeeklyMenuDay(day: current.day, meals: meals, source: current.source),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Comida actualizada.')));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo cambiar la comida: ${NutritionAiService.menuMessageFor(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete(User user, WeeklyMenuDay menu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar el menú de hoy?'),
        content: const Text(
          'Se eliminarán las comidas guardadas de hoy. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (!_isToday || FirebaseAuth.instance.currentUser?.uid != user.uid) {
        throw StateError(
          'La fecha o la sesión cambiaron. Vuelve a abrir esta pantalla.',
        );
      }
      await _repository.deleteDailyMenu(user.uid, _date, menu);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El menú de hoy fue eliminado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo eliminar el menú. Si cambió, vuelve a abrir esta pantalla.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menú del día'),
        backgroundColor: AppColors.background,
      ),
      body: user == null
          ? const Center(child: Text('Inicia sesión para ver tu menú.'))
          : StreamBuilder<UserNutritionProfile?>(
              stream: _repository.watch(user.uid),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.hasError) {
                  return const Center(
                    child: Text('No se pudo cargar tu perfil.'),
                  );
                }
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = profileSnapshot.data;
                if (profile == null) {
                  return const Center(
                    child: Text('Completa primero tu perfil.'),
                  );
                }
                return StreamBuilder<WeeklyMenuDay?>(
                  stream: _repository.watchDailyMenu(user.uid, _date),
                  builder: (context, menuSnapshot) {
                    if (menuSnapshot.hasError) {
                      return const Center(
                        child: Text('No se pudo cargar el menú de hoy.'),
                      );
                    }
                    if (menuSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final menu = menuSnapshot.data;
                    final canGenerate =
                        profile.hasProfileDetails &&
                        profile.country.trim().isNotEmpty;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const Text(
                              'Tu menú de hoy',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              menu == null
                                  ? 'Genera una propuesta con desayuno, almuerzo, snack y cena.'
                                  : 'Estas comidas ya están guardadas para hoy.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (menu == null) ...[
                              if (!canGenerate)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Completa edad, estatura, peso y país en tu perfil para generar el menú.',
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _working || !canGenerate
                                      ? null
                                      : () => _generate(user, profile),
                                  icon: const Icon(Icons.auto_awesome_outlined),
                                  label: const Text(
                                    'Generar menú del día con IA',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'La creación y edición manual estarán disponibles próximamente.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ] else ...[
                              if (menu.source == 'default')
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Menú predeterminado orientativo, no personalizado. Revisa los alimentos antes de consumirlos.',
                                  ),
                                ),
                              ...menu.meals.map(
                                (meal) => Card(
                                  child: ListTile(
                                    title: Text('${meal.type}: ${meal.name}'),
                                    subtitle: Text(meal.description),
                                    trailing: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          meal.calories > 0
                                              ? '${meal.calories} kcal'
                                              : '---',
                                        ),
                                        InkWell(
                                          onTap: _working
                                              ? null
                                              : () => _changeMeal(
                                                  user,
                                                  menu,
                                                  meal,
                                                ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Text(
                                              'Cambiar',
                                              style: TextStyle(
                                                color: Color(0xFF385746),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _working || !canGenerate
                                    ? null
                                    : () => _generate(
                                        user,
                                        profile,
                                        replacing: menu,
                                      ),
                                icon: const Icon(Icons.auto_awesome_outlined),
                                label: const Text('Regenerar menú con IA'),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _working
                                    ? null
                                    : () => _delete(user, menu),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Eliminar menú de hoy'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFD3E9D9),
                                  foregroundColor: const Color(0xFF2C4A3E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'La edición del menú estará disponible próximamente.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (_working) ...[
                              const SizedBox(height: 20),
                              const Center(child: CircularProgressIndicator()),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
