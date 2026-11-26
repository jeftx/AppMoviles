import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/navigation/quick_actions_menu.dart';
import 'package:flutter_app/core/navigation/more_menu.dart';

void main() {
  testWidgets('abre las cinco opciones y se cierra con la equis', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuickActionsButton())),
    );
    await tester.tap(find.byType(QuickActionsButton));
    await tester.pumpAndSettle();

    expect(find.text('Añadir menú personalizado'), findsOneWidget);
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Añadir alimento'), findsOneWidget);
    expect(find.text('Escanear comida'), findsOneWidget);
    expect(find.text('Generar menú aleatorio'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Escanear comida'), findsNothing);
  });

  testWidgets('abre la pantalla de construcción para una opción pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuickActionsButton())),
    );
    await tester.tap(find.byType(QuickActionsButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generar menú aleatorio'));
    await tester.pumpAndSettle();
    expect(find.text('En construcción'), findsOneWidget);
    expect(
      find.text('Generar menú aleatorio estará disponible próximamente.'),
      findsOneWidget,
    );
  });

  testWidgets('categorías del menú lateral abre la pantalla de categorías', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMoreMenu(context, onProfile: () {}),
              child: const Text('Abrir Más'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Proteína'), findsOneWidget);
    expect(find.text('Carbohidrato'), findsOneWidget);
    expect(find.text('Ensaladas'), findsOneWidget);
  });
}
