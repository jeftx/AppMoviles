import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/ai/nutrition_models.dart';

class UserFood {
  const UserFood({required this.title, required this.category, this.calories});
  final String title;
  final FoodCategory category;
  final double? calories;

  factory UserFood.fromMap(Map<String, dynamic> data) => UserFood(
    title: data['title'] as String? ?? '',
    category:
        FoodCategory.parse(data['category'] as String? ?? '') ??
        FoodCategory.otro,
    calories: (data['calories'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'category': category.name,
    if (calories != null) 'calories': calories,
  };
}

class FoodsRepository {
  FoodsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> _foods(String uid) =>
      _firestore.collection('users').doc(uid).collection('foods');
  Stream<List<UserFood>> watch(String uid) => _foods(uid).snapshots().map(
    (snapshot) =>
        snapshot.docs.map((doc) => UserFood.fromMap(doc.data())).toList(),
  );
  Future<void> add(String uid, UserFood food) async {
    await _foods(uid)
        .add({...food.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }
}
