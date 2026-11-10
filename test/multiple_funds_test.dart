import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inverto/main.dart';

void main() {
  testWidgets('funds preserve legacy data and keep contributions separate', (
    tester,
  ) async {
    await initializeDateFormatting('es_ES');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'invested_total': 1000.0,
      'fund_value': 1100.0,
    });
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir fondo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fondo global');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aportar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString('active_fund');
    expect(preferences.getDouble('fund_${id}_invested_total'), 250);
    expect(preferences.getDouble('invested_total'), 1000);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi fondo').last);
    await tester.pumpAndSettle();
    expect(find.text('€ 1100,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    expect(find.text('€ 1100,00'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fondo global').last);
    await tester.pumpAndSettle();
    expect(find.text('€ 250,00'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

