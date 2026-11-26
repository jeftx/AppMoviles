import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/nutrition_profile_repository.dart';
import '../../data/profile_details_update.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.profile,
    required this.userId,
    required this.onCancel,
    required this.onSaved,
  });

  final UserNutritionProfile profile;
  final String userId;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _health;
  late String _sex;
  late String _activity;
  late String _goal;
  late String _country;
  late Set<String> _restrictions;
  bool _saving = false;
  String? _error;

  static const _countries = [
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
  ];
  static const _activities = ['Sedentaria', 'Ligera', 'Moderada', 'Alta'];
  static const _sexes = ['Mujer', 'Hombre', 'Prefiero no decirlo'];
  static const _goals = [
    'Bajar de peso',
    'Mantener peso',
    'Ganar masa muscular',
  ];
  static const _restrictionOptions = [
    'Sin lactosa',
    'Sin gluten',
    'Vegetariana',
    'Vegana',
    'Diabetes',
    'Alergia a frutos secos',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final hasDetails = p.hasProfileDetails;
    _age = TextEditingController(
      text: hasDetails && p.age > 0 ? '${p.age}' : '',
    );
    _height = TextEditingController(
      text: hasDetails && p.heightCm > 0 ? _format(p.heightCm) : '',
    );
    _weight = TextEditingController(
      text: hasDetails && p.weightKg > 0 ? _format(p.weightKg) : '',
    );
    _health = TextEditingController(text: p.healthNotes);
    _sex = p.sex;
    _activity = p.activityLevel;
    _goal = p.goal;
    _country = p.country;
    _restrictions = p.restrictions.where((value) => value != 'Ninguna').toSet();
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _health.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_formKey.currentState!.validate()) return;
    if (FirebaseAuth.instance.currentUser?.uid != widget.userId) {
      setState(() => _error = 'La sesión cambió. Inicia sesión nuevamente.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final details = ProfileDetailsUpdate(
        age: int.parse(_age.text.trim()),
        heightCm: double.parse(_height.text.trim().replaceAll(',', '.')),
        weightKg: double.parse(_weight.text.trim().replaceAll(',', '.')),
        sex: _sex,
        activityLevel: _activity,
        country: _country,
        restrictions: _restrictions.toList()..sort(),
        healthNotes: _health.text.trim(),
        goal: _goal,
      );
      await NutritionProfileRepository().updateProfileDetails(
        widget.userId,
        widget.profile,
        details,
      );
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron guardar tus datos. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _numberValidator(
    String? text,
    double min,
    double max, {
    bool integer = false,
  }) {
    final value = text?.trim().replaceAll(',', '.') ?? '';
    final number = integer
        ? int.tryParse(value)?.toDouble()
        : double.tryParse(value);
    if (number == null || !number.isFinite || number < min || number > max) {
      return 'Ingresa un valor entre ${min.toInt()} y ${max.toInt()}.';
    }
    return null;
  }

  List<String> _includingCurrent(List<String> options, String current) =>
      current.trim().isNotEmpty && !options.contains(current)
      ? [...options, current]
      : options;

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    bool requiredValue = false,
  }) {
    final all = _includingCurrent(options, value);
    return DropdownButtonFormField<String>(
      initialValue: value.trim().isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: all
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      validator: requiredValue
          ? (item) =>
                item == null || item.isEmpty ? 'Selecciona una opción.' : null
          : null,
      onChanged: _saving
          ? null
          : (item) {
              if (item != null) setState(() => onChanged(item));
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = {..._restrictionOptions, ..._restrictions}.toList();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edita tus datos directamente aquí.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _age,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Edad',
              suffixText: 'años',
            ),
            validator: (value) =>
                _numberValidator(value, 13, 120, integer: true),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final heightField = TextFormField(
                controller: _height,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Estatura',
                  suffixText: 'cm',
                ),
                validator: (value) => _numberValidator(value, 80, 250),
              );
              final weightField = TextFormField(
                controller: _weight,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Peso',
                  suffixText: 'kg',
                ),
                validator: (value) => _numberValidator(value, 20, 400),
              );
              if (constraints.maxWidth < 330) {
                return Column(
                  children: [
                    heightField,
                    const SizedBox(height: 12),
                    weightField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heightField),
                  const SizedBox(width: 12),
                  Expanded(child: weightField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'País',
            value: _country,
            options: _countries,
            requiredValue: true,
            onChanged: (value) => _country = value,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Actividad',
            value: _activity,
            options: _activities,
            requiredValue: true,
            onChanged: (value) => _activity = value,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Sexo (opcional)',
            value: _sex,
            options: _sexes,
            onChanged: (value) => _sex = value,
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Objetivo',
            value: _goal,
            options: _goals,
            requiredValue: true,
            onChanged: (value) => _goal = value,
          ),
          const SizedBox(height: 18),
          const Text(
            'Restricciones o preferencias',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Ninguna'),
                selected: _restrictions.isEmpty,
                selectedColor: const Color(0xFFD3E9D9),
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _restrictions.clear()),
              ),
              ...options.map(
                (item) => FilterChip(
                  label: Text(item),
                  selected: _restrictions.contains(item),
                  selectedColor: const Color(0xFFD3E9D9),
                  onSelected: _saving
                      ? null
                      : (selected) => setState(() {
                          if (selected) {
                            _restrictions.add(item);
                          } else {
                            _restrictions.remove(item);
                          }
                        }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _health,
            enabled: !_saving,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Salud y otras restricciones',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Si tienes una enfermedad o una dieta indicada, consulta a un profesional. Las recomendaciones no sustituyen el asesoramiento médico.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : widget.onCancel,
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}
