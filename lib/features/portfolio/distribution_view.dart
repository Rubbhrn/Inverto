import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/services/portfolio_storage_service.dart';

class DistributionView extends StatefulWidget {
  const DistributionView({super.key, required this.funds});

  final Map<String, String> funds;

  @override
  State<DistributionView> createState() => _DistributionViewState();
}

class _DistributionViewState extends State<DistributionView> {
  final _storage = const PortfolioStorageService();
  late Future<Map<String, ({double invested, double value})>> _values;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DistributionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.funds != widget.funds) _load();
  }

  void _load() => _values = _storage.loadFundValues(widget.funds);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _values,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final values = snapshot.data ?? {};
      final total = values.values.fold<double>(
        0,
        (sum, item) => sum + item.value,
      );
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Distribución por fondo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'El gráfico reparte el valor actual de la cartera entre todos tus fondos.',
          ),
          const SizedBox(height: 18),
          _PortfolioPieCard(funds: widget.funds, values: values, total: total),
          const SizedBox(height: 14),
          _TotalCard(total: total, fundCount: widget.funds.length),
        ],
      );
    },
  );
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.fundCount});
  final double total;
  final int fundCount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Valor total de la cartera',
            style: TextStyle(color: Color(0xFF737D78)),
          ),
          const SizedBox(height: 4),
          Text(
            _money(total),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('$fundCount ${fundCount == 1 ? 'fondo' : 'fondos'}'),
        ],
      ),
    ),
  );
}

class _PortfolioPieCard extends StatelessWidget {
  const _PortfolioPieCard({
    required this.funds,
    required this.values,
    required this.total,
  });

  final Map<String, String> funds;
  final Map<String, ({double invested, double value})> values;
  final double total;

  static const _colors = [
    Color(0xFF176B52),
    Color(0xFF4D83C4),
    Color(0xFFE39A37),
    Color(0xFF9A72BD),
    Color(0xFFE06C64),
    Color(0xFF37A6A0),
    Color(0xFF738A36),
    Color(0xFFCC6F9B),
    Color(0xFF667085),
    Color(0xFF8C6B4F),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = funds.entries.toList();
    final activeEntries = entries
        .where((entry) => (values[entry.key]?.value ?? 0) > 0)
        .toList();
    final sections = activeEntries.isEmpty
        ? [
            PieChartSectionData(
              value: 1,
              color: const Color(0xFFE5EAE7),
              title: 'Sin datos',
              radius: 112,
              titleStyle: const TextStyle(fontSize: 12),
            ),
          ]
        : [
            for (var index = 0; index < activeEntries.length; index++)
              PieChartSectionData(
                value: values[activeEntries[index].key]!.value,
                color:
                    _colors[entries.indexOf(activeEntries[index]) %
                        _colors.length],
                title: total <= 0
                    ? ''
                    : '${(values[activeEntries[index].key]!.value / total * 100).toStringAsFixed(0)}%',
                radius: 112,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 36,
                  sectionsSpace: activeEntries.length > 1 ? 3 : 0,
                  pieTouchData: PieTouchData(enabled: false),
                ),
              ),
            ),
            const Divider(height: 24),
            for (var index = 0; index < entries.length; index++)
              _FundLegendRow(
                name: entries[index].value,
                value: values[entries[index].key]?.value ?? 0,
                total: total,
                color: _colors[index % _colors.length],
              ),
          ],
        ),
      ),
    );
  }
}

class _FundLegendRow extends StatelessWidget {
  const _FundLegendRow({
    required this.name,
    required this.value,
    required this.total,
    required this.color,
  });

  final String name;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${total <= 0 ? '0,0' : (value / total * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
          style: const TextStyle(color: Color(0xFF737D78)),
        ),
        const SizedBox(width: 12),
        Text(
          _money(value),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

String _money(double value) =>
    '€ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
