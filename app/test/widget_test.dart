import 'package:apply_to_anything/main.dart';
import 'package:apply_to_anything/models/job.dart';
import 'package:apply_to_anything/widgets/swipe_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('la app arranca, completa el boot y muestra el login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ApplyToAnythingApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Sin sesión guardada, el Root debe mostrar LoginScreen.
    expect(find.text('¿No tienes cuenta? Crear cuenta'), findsOneWidget);
    expect(find.text('Tu próximo trabajo está a un swipe'), findsOneWidget);
    expect(find.text('Configurar conexión'), findsOneWidget);

    await tester.tap(find.text('Portafolio'));
    await tester.pumpAndSettle();
    expect(find.text('Nelson Vera'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('EstadoFlow'), 180);
    expect(find.text('EstadoFlow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('se puede volver a decidir sobre la misma oferta',
      (tester) async {
    final controller = SwipeDeckController();
    final job = Job.fromJson({
      'id': 'job-1',
      'title': 'Soporte técnico',
      'company': 'Demo',
    });
    final decisions = <SwipeDir>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeDeck(
          jobs: [job],
          controller: controller,
          onDecide: (job, dir) => decisions.add(dir),
        ),
      ),
    ));
    controller.swipe(SwipeDir.right);
    await tester.pumpAndSettle();
    controller.swipe(SwipeDir.up);
    await tester.pumpAndSettle();

    expect(decisions, [SwipeDir.right, SwipeDir.up]);
  });
}
