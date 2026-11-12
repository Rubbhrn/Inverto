import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inverto/main.dart';

void main() {
  testWidgets('calendar selection shows that date contribution total', (
    tester,
  ) async {
    await initializeDateFormatting('es_ES');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'invested_total': 1000.0,
      'fund_value': 1100.0,
      'daily_date': dateKey,
      'daily_opening_value': 1050.0,
      'today_contributions': 50.0,
      'contributions': jsonEncode([
        {'amount': 20.0, 'date': today.toIso8601String()},
        {'amount': 30.0, 'date': today.toIso8601String()},
      ]),
      'daily_history': '[]',
    });

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    expect(find.text('Calendario diario'), findsOneWidget);
    expect(find.text('Aportado este día'), findsOneWidget);
    expect(find.text('2 aportaciones'), findsOneWidget);
    expect(find.text('€ 50,00'), findsOneWidget);
    await tester.ensureVisible(find.text('Aportado este d\u00eda'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Aportado este día')).bottom,
      lessThan(844),
    );

    await tester.tap(find.text('Gráfico'));
    await tester.pumpAndSettle();
    expect(find.text('Evolución del fondo'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.single.spots.single.y, 1100);
    expect(chart.data.minY, greaterThan(0));

    await tester.tap(find.text('Principal'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(864, 648);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Aportado este d\u00eda'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Aportado este día')).bottom,
      lessThan(648),
    );
  });
}
