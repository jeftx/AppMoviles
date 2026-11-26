import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/ai/nutrition_models.dart';
import 'profile_details_update.dart';

class DailyMenuAlreadyExistsException implements Exception {
  const DailyMenuAlreadyExistsException();
}

class NutritionProfileRepository {
  NutritionProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DocumentReference<Map<String, dynamic>> _document(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserNutritionProfile?> watch(String uid) =>
      _document(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return UserNutritionProfile.fromMap(snapshot.data()!);
      });

  Future<void> save(String uid, UserNutritionProfile profile, {String? email}) {
    final data = profile.toMap();
    // Un perfil sin menú semanal no debe borrar el indicador de un menú existente.
    if (profile.weeklyMenu == null) data.remove('hasWeeklyMenu');
    return _document(uid).set({
      ...data,
      if (email != null) 'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveWeeklyMenu(String uid, WeeklyMenu weeklyMenu) =>
      _document(uid).set({
        'weeklyMenu': weeklyMenu.toJson(),
        'hasWeeklyMenu': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> updateProfileDetails(
    String uid,
    UserNutritionProfile original,
    ProfileDetailsUpdate details,
  ) => _document(uid).update({
    ...details.toMap(original),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  DocumentReference<Map<String, dynamic>> _dailyMenu(String uid, String date) =>
      _document(uid).collection('dailyMenus').doc(date);

  Stream<WeeklyMenuDay?> watchDailyMenu(String uid, String date) =>
      _dailyMenu(uid, date).snapshots().map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : WeeklyMenuDay.fromJson(data);
      });

  Future<void> saveDailyMenu(String uid, String date, WeeklyMenuDay menu) =>
      _firestore.runTransaction((transaction) async {
        final ref = _dailyMenu(uid, date);
        final existing = await transaction.get(ref);
        if (existing.exists) throw const DailyMenuAlreadyExistsException();
        transaction.set(ref, {
          ...menu.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> replaceDailyMenu(
    String uid,
    String date,
    WeeklyMenuDay expected,
    WeeklyMenuDay replacement,
  ) {
    final retained = replacement.meals
        .map((meal) => jsonEncode(meal.toJson()))
        .toSet();
    final displaced = expected.meals
        .where((meal) => !retained.contains(jsonEncode(meal.toJson())))
        .toList();
    final archive = _document(uid).collection('savedMeals');
    final archiveRefs = List.generate(displaced.length, (_) => archive.doc());
    return _firestore.runTransaction((transaction) async {
      final ref = _dailyMenu(uid, date);
      final data = (await transaction.get(ref)).data();
      if (data == null ||
          jsonEncode(WeeklyMenuDay.fromJson(data).toJson()) !=
              jsonEncode(expected.toJson())) {
        throw StateError(
          'El menú cambió. Actualiza la pantalla y vuelve a intentarlo.',
        );
      }
      for (var i = 0; i < displaced.length; i++) {
        transaction.set(archiveRefs[i], {
          ...displaced[i].toJson(),
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(ref, {
        ...replacement.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<MenuMeal>> savedMeals(
    String uid,
    String date,
    String type,
  ) async {
    final savedSnapshot = await _document(uid).collection('savedMeals').get();
    final snapshot = await _document(uid)
        .collection('dailyMenus')
        .limit(50)
        .get();
    final meals = <MenuMeal>[
      ...savedSnapshot.docs
          .map((doc) => MenuMeal.fromJson(doc.data()))
          .where((meal) => meal.type.toLowerCase() == type.toLowerCase()),
    ];
    for (final doc in snapshot.docs) {
      if (doc.id == date) continue;
      meals.addAll(
        WeeklyMenuDay.fromJson(doc.data()).meals
            .where((meal) => meal.type.toLowerCase() == type.toLowerCase()),
      );
    }
    final unique = <String, MenuMeal>{};
    for (final meal in meals) {
      unique.putIfAbsent(jsonEncode(meal.toJson()), () => meal);
    }
    return unique.values.toList();
  }

  Future<void> deleteDailyMenu(
    String uid,
    String date,
    WeeklyMenuDay expected,
  ) => _firestore.runTransaction((transaction) async {
    final ref = _dailyMenu(uid, date);
    final data = (await transaction.get(ref)).data();
    if (data == null ||
        jsonEncode(WeeklyMenuDay.fromJson(data).toJson()) !=
            jsonEncode(expected.toJson())) {
      throw StateError(
        'El menú cambió. Actualiza la pantalla antes de eliminarlo.',
      );
    }
    transaction.delete(ref);
  });

  Future<void> saveDailyMealDetails(
    String uid,
    String date,
    MenuMeal original,
    MenuMeal details,
  ) => _firestore.runTransaction((transaction) async {
    final ref = _dailyMenu(uid, date);
    final snapshot = await transaction.get(ref);
    final data = snapshot.data();
    if (data == null) throw StateError('El menú del día ya no existe.');
    final day = WeeklyMenuDay.fromJson(data);
    final index = day.meals.indexWhere(
      (meal) =>
          meal.type == original.type &&
          meal.name == original.name &&
          (original.id.isEmpty || meal.id == original.id),
    );
    if (index < 0) {
      throw StateError('La comida cambió mientras se generaba la receta.');
    }
    final meals = List<MenuMeal>.from(day.meals);
    meals[index] = details;
    transaction.update(ref, {
      'meals': meals.map((meal) => meal.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<void> removeDailyMeal(String uid, String date, MenuMeal original) =>
      _firestore.runTransaction((transaction) async {
        final ref = _dailyMenu(uid, date);
        final data = (await transaction.get(ref)).data();
        if (data == null) throw StateError('El menú del día ya no existe.');
        final day = WeeklyMenuDay.fromJson(data);
        final meals = day.meals
            .where(
              (meal) =>
                  !(meal.type == original.type &&
                      meal.name == original.name &&
                      (original.id.isEmpty || meal.id == original.id)),
            )
            .toList();
        if (meals.length == day.meals.length) {
          throw StateError('La comida ya no existe.');
        }
        if (meals.isEmpty) {
          transaction.delete(ref);
        } else {
          transaction.update(ref, {
            'meals': meals.map((meal) => meal.toJson()).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

  Future<void> removeMeal(
    String uid,
    WeeklyMenu weeklyMenu, {
    required int dayIndex,
    required int mealIndex,
  }) {
    if (dayIndex < 0 || dayIndex >= weeklyMenu.days.length) {
      throw ArgumentError.value(dayIndex, 'dayIndex', 'Día de menú inválido.');
    }
    final targetDay = weeklyMenu.days[dayIndex];
    if (mealIndex < 0 || mealIndex >= targetDay.meals.length) {
      throw ArgumentError.value(
        mealIndex,
        'mealIndex',
        'Comida de menú inválida.',
      );
    }

    final updatedMeals = List<MenuMeal>.from(targetDay.meals)
      ..removeAt(mealIndex);
    final updatedDays = List<WeeklyMenuDay>.from(weeklyMenu.days);
    updatedDays[dayIndex] = WeeklyMenuDay(
      day: targetDay.day,
      meals: updatedMeals,
    );
    final updatedMenu = WeeklyMenu(
      dailyCalories: weeklyMenu.dailyCalories,
      source: weeklyMenu.source,
      days: updatedDays,
    );

    return _document(uid).set({
      'weeklyMenu': updatedMenu.toJson(),
      'hasWeeklyMenu': updatedDays.any((day) => day.meals.isNotEmpty),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _dailyLog(
    String uid,
    String dayKey,
  ) => _document(uid).collection('dailyLogs').doc(dayKey);

  Stream<int> watchWater(String uid, String dayKey) => _dailyLog(uid, dayKey)
      .snapshots()
      .map((snapshot) => (snapshot.data()?['waterMl'] as num?)?.round() ?? 0);

  Future<void> addWater(String uid, String dayKey, {int amountMl = 250}) =>
      _dailyLog(uid, dayKey).set({
        'waterMl': FieldValue.increment(amountMl),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
