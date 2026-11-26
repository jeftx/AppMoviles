import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/nutrition/water_goal.dart';
import 'package:flutter_app/core/nutrition/water_goal_card.dart';

void main() {
  test('usa peso dividido entre siete y redondea a vasos completos', () {
    expect(dailyWaterGlasses(70), 10);
    expect(dailyWaterGoalMl(70), 2500);
    expect(dailyWaterGlasses(71), 11);
    expect(dailyWaterGoalMl(71), 2750);
    expect(dailyWaterGlasses(0), 0);
    expect(dailyWaterGlasses(double.nan), 0);
  });

  testWidgets('muestra una línea por vaso sin controles de consumo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WaterGoalCard(weightKg: 70))),
    );
    expect(find.text('Meta diaria: 10 vasos · 2500 ml'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      expect(find.byKey(ValueKey('water-glass-$i')), findsOneWidget);
    }
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('sin peso no inventa una meta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WaterGoalCard(weightKg: null))),
    );
    expect(find.text('Agrega tu peso para calcular la meta'), findsOneWidget);
    expect(find.byKey(const ValueKey('water-glass-0')), findsNothing);
  });
}
