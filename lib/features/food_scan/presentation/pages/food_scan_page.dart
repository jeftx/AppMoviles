import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/ai/nutrition_ai_service.dart';
import '../../../../core/ai/nutrition_models.dart';
import '../../../../core/theme/app_colors.dart';

class FoodScanPage extends StatefulWidget {
  const FoodScanPage({super.key});

  @override
  State<FoodScanPage> createState() => _FoodScanPageState();
}

class _FoodScanPageState extends State<FoodScanPage> {
  final _imagePicker = ImagePicker();
  static const _manualFoods = [
    FoodItem(name: 'Pan', calories: 133, portionGrams: 50, notes: 'Porción mediana'),
    FoodItem(name: 'Arroz cocido', calories: 195, portionGrams: 150, notes: 'Una taza pequeña'),
    FoodItem(name: 'Pechuga de pollo', calories: 198, portionGrams: 120, notes: 'Porción cocida'),
    FoodItem(name: 'Huevo', calories: 78, portionGrams: 50, notes: 'Una unidad'),
    FoodItem(name: 'Banano', calories: 105, portionGrams: 118, notes: 'Una unidad mediana'),
    FoodItem(name: 'Ensalada mixta', calories: 90, portionGrams: 180, notes: 'Sin aderezo'),
  ];
  XFile? _image;
  FoodAnalysis? _analysis;
  String? _error;
  bool _isAnalyzing = false;

  Future<void> _takePhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    setState(() {
      _image = image;
      _analysis = null;
      _error = null;
    });
    await _analyze(image);
  }

  Future<void> _analyze(XFile image) async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final analysis = await NutritionAiService.analyzeMealPhoto(
        await image.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => _analysis = analysis);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = NutritionAiService.userMessageFor(error);
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _showManualFoodPicker() async {
    final food = await showModalBottomSheet<FoodItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrar alimento manualmente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text('Elige una opción para obtener una estimación inmediata.'),
              const SizedBox(height: 10),
              ..._manualFoods.map(
                (food) => ListTile(
                  leading: const Icon(Icons.restaurant_outlined),
                  title: Text(food.name),
                  subtitle: Text('${food.portionGrams.round()} g · ${food.calories} kcal'),
                  onTap: () => Navigator.pop(context, food),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (food == null || !mounted) return;

    setState(() {
      _error = null;
      _analysis = FoodAnalysis(
        foods: [food],
        totalCalories: food.calories,
        summary: '${food.name} registrado manualmente.',
        confidenceNote:
            'Estimación de referencia. Puedes usarla cuando la IA no esté disponible.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Escanear comida'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Toma una foto de tu plato',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'La IA reconocerá los alimentos visibles y estimará sus calorías.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 22),
            _PhotoPreview(image: _image),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isAnalyzing ? null : _takePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_image == null ? 'Tomar foto' : 'Tomar otra foto'),
            ),
            TextButton.icon(
              onPressed: _isAnalyzing ? null : _showManualFoodPicker,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Registrar alimento manualmente'),
            ),
            if (_isAnalyzing) ...[
              const SizedBox(height: 30),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(child: Text('Analizando tu comida con IA...')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              _MessageCard(message: _error!, isError: true),
            ],
            if (_analysis != null) ...[
              const SizedBox(height: 24),
              _AnalysisCard(analysis: _analysis!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final XFile? image;

  const _PhotoPreview({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 245,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECEF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: image == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_outlined, size: 54, color: AppColors.primaryDark),
                  SizedBox(height: 10),
                  Text('Enfoca el plato completo'),
                ],
              ),
            )
          : Image.file(File(image!.path), fit: BoxFit.cover, width: double.infinity),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final FoodAnalysis analysis;

  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Resultado estimado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              Text('${analysis.totalCalories} kcal', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            ],
          ),
          if (analysis.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(analysis.summary),
          ],
          const SizedBox(height: 14),
          ...analysis.foods.map(
            (food) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${food.name} · ${food.portionGrams.round()} g${food.notes.isEmpty ? '' : '\n${food.notes}'}')),
                  Text('${food.calories} kcal'),
                ],
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            analysis.confidenceNote,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFECEC) : const Color(0xFFF3ECEF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message),
      );
}
