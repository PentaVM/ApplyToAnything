import 'package:apply_to_anything/core/api.dart';
import 'package:apply_to_anything/screens/applications_screen.dart';
import 'package:apply_to_anything/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _ApplicationsApi extends ApiClient {
  _ApplicationsApi() : super('https://example.com');

  final record = <String, dynamic>{
    'id': 1,
    'job_id': 'test:1',
    'title': 'Soporte cloud',
    'company': 'Demo',
    'url': 'https://example.com/job',
    'status': 'applied',
    'method': 'external_url',
  };
  Map<String, dynamic>? confirmation;

  @override
  Future<dynamic> get(String path, [Map<String, String>? query]) async => {
        'applications': [record]
      };

  @override
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    confirmation = body;
    record['method'] = 'manual_confirmation';
    return {'ok': true};
  }
}

class _ApplicationsState extends AppState {
  _ApplicationsState(this.api);

  @override
  final _ApplicationsApi api;
}

void main() {
  testWidgets('un registro previo requiere confirmar el envío', (tester) async {
    final api = _ApplicationsApi();
    final state = _ApplicationsState(api);
    addTearDown(state.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: ApplicationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('envío por confirmar'), findsOneWidget);

    await tester.tap(find.byTooltip('Opciones de la oferta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar como enviada'));
    await tester.pumpAndSettle();
    expect(api.confirmation, isNull);

    await tester.tap(find.text('Sí, ya la envié'));
    await tester.pumpAndSettle();
    expect(
        api.confirmation, {'status': 'applied', 'confirmed_submission': true});

    await tester.tap(find.text('Enviadas'));
    await tester.pumpAndSettle();
    expect(find.text('Soporte cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
