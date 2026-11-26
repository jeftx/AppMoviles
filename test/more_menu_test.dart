import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/navigation/more_menu.dart';

void main() {
  testWidgets('el panel se adapta y abre Perfil desde celular y tableta', (
    tester,
  ) async {
    var openedProfile = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showMoreMenu(context, onProfile: () => openedProfile++),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    for (final size in [const Size(320, 640), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Menús personalizados'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Perfil')).dx,
        greaterThanOrEqualTo(0),
      );
      expect(tester.getTopRight(find.text('Perfil')).dx, lessThan(size.width));
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Menús personalizados'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(openedProfile, 2);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('en Perfil la opción seleccionada cierra sin volver a navegar', (
    tester,
  ) async {
    var navigations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMoreMenu(
                context,
                isProfile: true,
                onProfile: () => navigations++,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(navigations, 0);
    expect(find.text('Menús personalizados'), findsNothing);
  });
}
