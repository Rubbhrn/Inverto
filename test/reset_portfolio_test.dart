import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inverto/main.dart';

void main() {
  testWidgets('confirmed reset clears the saved portfolio', (tester) async {
    await initializeDateFormatting('es_ES');
    SharedPreferences.setMockInitialValues({
      'invested_total': 1000.0,
      'fund_value': 1100.0,
      'daily_date': '2026-11-08',
      'daily_opening_value': 1000.0,
      'today_contributions': 0.0,
      'contributions': '[]',
      'daily_history': '[]',
    });

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reiniciar datos'));
    await tester.pumpAndSettle();
    expect(find.text('Reiniciar fondo'), findsOneWidget);

    await tester.tap(find.text('Reiniciar'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('invested_total'), 0);
    expect(preferences.getDouble('fund_value'), 0);
    expect(preferences.getString('contributions'), '[]');
    expect(preferences.getString('daily_history'), '[]');
    expect(find.text('Reiniciar fondo'), findsNothing);
  });
}
