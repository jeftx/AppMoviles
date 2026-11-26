import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/ai/nutrition_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../home_screen.dart';
import '../../profile/presentation/pages/profile_page.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../../menu_generator/presentation/pages/daily_menu_generator_page.dart';
import '../../foods/data/foods_repository.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  static const categories = [
    (FoodCategory.proteina, '🥚', Color(0xFFF8E4EB)),
    (FoodCategory.carbohidrato, '🍚', Color(0xFFCFE2D4)),
    (FoodCategory.ensalada, '🥗', Color(0xFFDDD5EE)),
    (FoodCategory.verdura, '🥦', Color(0xFFF8E4EB)),
    (FoodCategory.sopa, '🍲', Color(0xFFCFE2D4)),
    (FoodCategory.fruta, '🍎', Color(0xFFDDD5EE)),
    (FoodCategory.snack, '🥜', Color(0xFFF8E4EB)),
    (FoodCategory.jugo, '🧃', Color(0xFFCFE2D4)),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    bottomNavigationBar: HomeBottomNavigation(
      onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onGenerate: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DailyMenuGeneratorPage()),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: StreamBuilder<List<UserFood>>(
            stream:
                Firebase.apps.isNotEmpty &&
                    FirebaseAuth.instance.currentUser != null
                ? FoodsRepository().watch(
                    FirebaseAuth.instance.currentUser!.uid,
                  )
                : null,
            builder: (context, snapshot) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                          'Categorías',
                          style: GoogleFonts.quicksand(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const Spacer(),
                        if (Firebase.apps.isNotEmpty &&
                            FirebaseAuth.instance.currentUser != null)
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ProfilePage(),
                              ),
                            ),
                            child: ProfileAvatar(
                              name:
                                  FirebaseAuth.instance.currentUser!.displayName
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .displayName!
                                  : (FirebaseAuth.instance.currentUser!.email
                                            ?.split('@')
                                            .first ??
                                        'Usuario'),
                              radius: 21,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 170,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final (category, emoji, color) = categories[index];
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 30)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.label,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  snapshot.hasError
                                      ? 'No disponible'
                                      : !snapshot.hasData
                                      ? '—'
                                      : '${snapshot.data!.where((food) => food.category == category).length} alimentos',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }, childCount: categories.length),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
