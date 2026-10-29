import 'package:apply_to_anything/main.dart';
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
  });
}
