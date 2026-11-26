import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/ai/nutrition_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../home_screen.dart';
import '../../categories/presentation/categories_page.dart';
import '../../menu_generator/presentation/pages/daily_menu_generator_page.dart';
import '../../profile/presentation/pages/profile_page.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../data/foods_repository.dart';

class FoodsPage extends StatefulWidget {
  const FoodsPage({super.key});
  @override
  State<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends State<FoodsPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: HomeBottomNavigation(
        onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
        onGenerate: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DailyMenuGeneratorPage(),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Volver',
                      ),
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.eco_outlined,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        'Alimentos',
                        style: GoogleFonts.quicksand(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (user != null)
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfilePage(),
                            ),
                          ),
                          customBorder: const CircleBorder(),
                          child: ProfileAvatar(
                            name: user.displayName?.trim().isNotEmpty == true
                                ? user.displayName!
                                : (user.email?.split('@').first ?? 'Usuario'),
                            radius: 21,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: user == null
                      ? const Center(
                          child: Text('Inicia sesión para ver tus alimentos.'),
                        )
                      : StreamBuilder<List<UserFood>>(
                          stream: FoodsRepository().watch(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'No se pudieron cargar tus alimentos.',
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final foods =
                                snapshot.data!
                                    .where(
                                      (food) =>
                                          food.title.toLowerCase().contains(
                                            _query.trim().toLowerCase(),
                                          ),
                                    )
                                    .toList()
                                  ..sort(
                                    (a, b) => a.title.toLowerCase().compareTo(
                                      b.title.toLowerCase(),
                                    ),
                                  );
                            return ListView(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              children: [
                                TextField(
                                  onChanged: (value) =>
                                      setState(() => _query = value),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar alimento',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (foods.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 28,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _query.trim().isEmpty
                                            ? 'Aún no tienes alimentos creados.'
                                            : 'No se encontraron alimentos.',
                                      ),
                                    ),
                                  ),
                                for (final food in foods)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 7,
                                            ),
                                        leading: Text(
                                          CategoriesPage.categories
                                                  .where(
                                                    (item) =>
                                                        item.$1 ==
                                                        food.category,
                                                  )
                                                  .map((item) => item.$2)
                                                  .firstOrNull ??
                                              '🍽️',
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                        title: Text(
                                          food.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(food.category.label),
                                        trailing: food.calories == null
                                            ? null
                                            : Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFCFE2D4,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${food.calories! % 1 == 0 ? food.calories!.toInt() : food.calories} kcal',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) =>
                                        _AddFoodDialog(uid: user.uid),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.primaryDark,
                                    minimumSize: const Size.fromHeight(54),
                                    shape: const StadiumBorder(),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Añadir alimento'),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog({required this.uid});
  final String uid;
  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _calories = TextEditingController();
  FoodCategory? _category;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (FirebaseAuth.instance.currentUser?.uid != widget.uid) {
      setState(() => _error = 'La sesión cambió. Vuelve a intentarlo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final text = _calories.text.trim().replaceAll(',', '.');
      await FoodsRepository().add(
        widget.uid,
        UserFood(
          title: _title.text,
          category: _category!,
          calories: text.isEmpty ? null : double.parse(text),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar el alimento. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Añadir alimento'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Título *'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe el título.'
                  : null,
            ),
            DropdownButtonFormField<FoodCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoría *'),
              items: CategoriesPage.categories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.$1,
                      child: Text(item.$1.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _category = value),
              validator: (value) =>
                  value == null ? 'Selecciona una categoría.' : null,
            ),
            TextFormField(
              controller: _calories,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Calorías (opcional)',
                suffixText: 'kcal',
              ),
              validator: (value) {
                final text = (value ?? '').trim().replaceAll(',', '.');
                if (text.isEmpty) return null;
                final number = double.tryParse(text);
                return number == null || !number.isFinite || number < 0
                    ? 'Escribe una cantidad válida.'
                    : null;
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando...' : 'Guardar'),
      ),
    ],
  );
}
