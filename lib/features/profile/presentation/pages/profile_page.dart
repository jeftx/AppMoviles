import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/navigation/more_menu.dart';
import '../../../../core/navigation/construction_page.dart';
import '../../../../core/navigation/quick_actions_menu.dart';
import '../../../menu_generator/presentation/pages/daily_menu_generator_page.dart';
import '../../../../core/ai/nutrition_models.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/nutrition_profile_repository.dart';
import '../widgets/profile_editor.dart';
import '../widgets/profile_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final fallbackName = _nameFor(user);
    final email = user?.email?.trim() ?? '';

    if (user == null) return const SizedBox.shrink();
    return StreamBuilder<UserNutritionProfile?>(
      stream: NutritionProfileRepository().watch(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = snapshot.data?.name ?? fallbackName;
        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: const _ProfileNavigation(),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileHeader(onTap: () => Navigator.of(context).pop()),
                      const SizedBox(height: 30),
                      Center(
                        child: Column(
                          children: [
                            ProfileAvatar(name: name, radius: 40),
                            const SizedBox(height: 14),
                            Text(name, style: _ProfileStyles.name),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(email, style: _ProfileStyles.email),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text('Mis datos', style: _ProfileStyles.sectionTitle),
                      const SizedBox(height: 14),
                      if (_editing && profile != null)
                        ProfileEditor(
                          profile: profile,
                          userId: user.uid,
                          onCancel: () => setState(() => _editing = false),
                          onSaved: () {
                            setState(() => _editing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Tus datos se guardaron correctamente.',
                                ),
                              ),
                            );
                          },
                        )
                      else ...[
                        if (snapshot.hasError)
                          const Text(
                            'No se pudieron cargar tus datos. Revisa tu conexión.',
                          )
                        else if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            profile == null)
                          const Center(child: CircularProgressIndicator())
                        else
                          _ProfileDataCard(profile: profile),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: profile == null || snapshot.hasError
                                ? null
                                : () => setState(() => _editing = true),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(
                              profile?.hasProfileDetails == true &&
                                      profile?.country.trim().isNotEmpty == true
                                  ? 'Editar mis datos'
                                  : 'Completar mis datos',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMain,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(25),
                          child: InkWell(
                            onTap: () => _signOut(context),
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Text(
                                'Cerrar sesión',
                                style: _ProfileStyles.signOut,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _nameFor(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Usuario';
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileHeader({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              Text('NutriMenu AI', style: _ProfileStyles.header),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDataCard extends StatelessWidget {
  final UserNutritionProfile? profile;

  const _ProfileDataCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null || !profile!.hasProfileDetails) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [AppTheme.globalShadow],
        ),
        child: const Text(
          'Aún no has completado tus datos. Agrégalos para recibir metas y menús personalizados.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      );
    }
    final currentProfile = profile!;
    final data = <(String, String)>[
      ('Edad', '${currentProfile.age} años'),
      ('Altura', '${_formatMeasurement(currentProfile.heightCm)} cm'),
      ('Peso', '${_formatMeasurement(currentProfile.weightKg)} kg'),
      ('Sexo', currentProfile.sex),
      ('Actividad', currentProfile.activityLevel),
      (
        'País',
        currentProfile.country.trim().isEmpty
            ? 'Pendiente'
            : currentProfile.country,
      ),
      (
        'Restricciones',
        currentProfile.restrictions.isEmpty
            ? 'Ninguna'
            : currentProfile.restrictions.join(', '),
      ),
      if (currentProfile.healthNotes.trim().isNotEmpty)
        ('Salud', currentProfile.healthNotes),
      ('Objetivo', currentProfile.goal),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [AppTheme.globalShadow],
      ),
      child: Column(
        children: List.generate(
          data.length,
          (index) => _ProfileDataRow(
            label: data[index].$1,
            value: data[index].$2,
            showDivider: index < data.length - 1,
          ),
        ),
      ),
    );
  }

  String _formatMeasurement(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class _ProfileDataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _ProfileDataRow({
    required this.label,
    required this.value,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          Text(label, style: _ProfileStyles.label),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: _ProfileStyles.value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileNavigation extends StatelessWidget {
  const _ProfileNavigation();

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
                onTap: () =>
                    showMoreMenu(context, isProfile: true, onProfile: () {}),
              ),
              _NavigationItem(
                icon: Icons.home_outlined,
                label: 'Inicio',
                onTap: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const QuickActionsButton(),
              _NavigationItem(
                icon: Icons.auto_awesome_outlined,
                label: 'Generar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DailyMenuGeneratorPage(),
                  ),
                ),
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
            Text(label, style: _ProfileStyles.navigation),
          ],
        ),
      ),
    );
  }
}

abstract class _ProfileStyles {
  static final header = GoogleFonts.quicksand(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final name = GoogleFonts.quicksand(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final email = GoogleFonts.nunito(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static final sectionTitle = GoogleFonts.quicksand(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final label = GoogleFonts.nunito(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static final value = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static final navigation = GoogleFonts.nunito(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  static final signOut = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );
}
