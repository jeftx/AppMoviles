import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

void openConstructionPage(BuildContext context, String feature) {
  Navigator.of(context).push(constructionRoute(feature));
}

MaterialPageRoute<void> constructionRoute(String feature) =>
    MaterialPageRoute<void>(builder: (_) => ConstructionPage(feature: feature));

class ConstructionPage extends StatelessWidget {
  const ConstructionPage({super.key, required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(backgroundColor: AppColors.background, title: Text(feature)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary,
              child: Icon(
                Icons.construction_rounded,
                size: 34,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'En construcción',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              '$feature estará disponible próximamente.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
