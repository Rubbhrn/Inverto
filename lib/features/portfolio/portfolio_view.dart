import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/models/contribution.dart';
import '../../core/models/daily_record.dart';
import 'distribution_view.dart';
import '../profile/profile_view.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage>
    with WidgetsBindingObserver {
  String _activeFund = 'default';
  Map<String, String> _funds = {'default': 'Mi fondo'};
  String _fundKey(String key) =>
      _activeFund == 'default' ? key : 'fund_${_activeFund}_$key';

  String get _investedKey => _fundKey('invested_total');
  String get _valueKey => _fundKey('fund_value');
  String get _contributionsKey => _fundKey('contributions');
  String get _dailyDateKey => _fundKey('daily_date');
  String get _dailyOpeningValueKey => _fundKey('daily_opening_value');
  String get _todayContributionsKey => _fundKey('today_contributions');
  String get _dailyHistoryKey => _fundKey('daily_history');

  double _invested = 0;
  double _fundValue = 0;
  double _dailyOpeningValue = 0;
  double _todayContributions = 0;
  String _dailyDate = '';
  List<Contribution> _contributions = [];
  Map<String, DailyRecord> _dailyRecords = {};
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _selectedTabIndex = 0;
  int _distributionRefresh = 0;
  bool _loading = true;
  Timer? _dailyResetTimer;

  double get _gain => _fundValue - _invested;
  double get _returnPercentage => _invested == 0 ? 0 : _gain / _invested * 100;
  double get _dailyGain =>
      _fundValue - _dailyOpeningValue - _todayContributions;
  double get _dailyReturnPercentage =>
      _dailyOpeningValue == 0 ? 0 : _dailyGain / _dailyOpeningValue * 100;
  DailyRecord get _currentDailyRecord => DailyRecord(
    dateKey: _dailyDate,
    openingValue: _dailyOpeningValue,
    closingValue: _fundValue,
    contributions: _todayContributions,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFunds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dailyResetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rollDailyWindowIfNeeded();
  }

  Future<void> _initializeFunds() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString('funds');
    if (stored != null) {
      _funds = Map<String, String>.from(jsonDecode(stored) as Map);
    }
    final selected = preferences.getString('active_fund');
    if (_funds.containsKey(selected)) _activeFund = selected!;
    await _loadPortfolio();
  }

  Future<void> _selectFund(String id) async {
    if (id == _activeFund) return;
    _dailyResetTimer?.cancel();
    await _savePortfolio();
    if (!mounted) return;
    setState(() {
      _activeFund = id;
      _loading = true;
      _focusedDay = DateTime.now();
      _selectedDay = _focusedDay;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('active_fund', id);
    await _loadPortfolio();
  }

  Future<void> _editFund({bool create = false}) async {
    final controller = TextEditingController(
      text: create ? '' : _funds[_activeFund],
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(create ? 'Añadir fondo' : 'Renombrar fondo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre del fondo',
            hintText: 'Por ejemplo, Fondo global',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (name == null || !mounted) return;
    final id = create
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : _activeFund;
    setState(() => _funds[id] = name);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('funds', jsonEncode(_funds));
    if (create) await _selectFund(id);
  }

  Widget _buildFundSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _activeFund,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Fondo seleccionado',
              prefixIcon: Icon(Icons.account_balance_outlined, size: 20),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            items: _funds.entries
                .map(
                  (fund) => DropdownMenuItem(
                    value: fund.key,
                    child: Text(fund.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) _selectFund(id);
            },
          ),
        ),
        IconButton(
          tooltip: 'Renombrar fondo',
          onPressed: () => _editFund(),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton.filled(
          tooltip: 'Añadir fondo',
          onPressed: () => _editFund(create: true),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Future<void> _loadPortfolio() async {
    final preferences = await SharedPreferences.getInstance();
    final storedContributions = preferences.getString(_contributionsKey);
    final contributions = <Contribution>[];
    final dailyRecords = <String, DailyRecord>{};
    final storedHistory = preferences.getString(_dailyHistoryKey);

    if (storedContributions != null) {
      try {
        final decoded = jsonDecode(storedContributions) as List<dynamic>;
        contributions.addAll(
          decoded.map(
            (item) => Contribution.fromJson(item as Map<String, dynamic>),
          ),
        );
      } on FormatException {
        await preferences.remove(_contributionsKey);
      } on TypeError {
        await preferences.remove(_contributionsKey);
      }
    }

    if (storedHistory != null) {
      try {
        final decoded = jsonDecode(storedHistory) as List<dynamic>;
        for (final item in decoded) {
          final record = DailyRecord.fromJson(item as Map<String, dynamic>);
          dailyRecords[record.dateKey] = record;
        }
      } on FormatException {
        await preferences.remove(_dailyHistoryKey);
      } on TypeError {
        await preferences.remove(_dailyHistoryKey);
      }
    }

    if (!mounted) return;
    final fundValue = preferences.getDouble(_valueKey) ?? 0;
    final today = _dayKey(DateTime.now());
    final storedDate = preferences.getString(_dailyDateKey);
    final isSameDay = storedDate == today;
    if (storedDate != null && !isSameDay) {
      dailyRecords[storedDate] = DailyRecord(
        dateKey: storedDate,
        openingValue: preferences.getDouble(_dailyOpeningValueKey) ?? fundValue,
        closingValue: fundValue,
        contributions: preferences.getDouble(_todayContributionsKey) ?? 0,
      );
    }
    setState(() {
      _invested = preferences.getDouble(_investedKey) ?? 0;
      _fundValue = fundValue;
      _dailyDate = today;
      _dailyOpeningValue = isSameDay
          ? preferences.getDouble(_dailyOpeningValueKey) ?? fundValue
          : fundValue;
      _todayContributions = isSameDay
          ? preferences.getDouble(_todayContributionsKey) ?? 0
          : 0;
      _contributions = contributions;
      _dailyRecords = dailyRecords;
      _loading = false;
    });
    await _savePortfolio();
    _scheduleDailyReset();
  }

  Future<void> _savePortfolio() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_investedKey, _invested);
    await preferences.setDouble(_valueKey, _fundValue);
    await preferences.setString(_dailyDateKey, _dailyDate);
    await preferences.setDouble(_dailyOpeningValueKey, _dailyOpeningValue);
    await preferences.setDouble(_todayContributionsKey, _todayContributions);
    await preferences.setString(
      _dailyHistoryKey,
      jsonEncode(
        _dailyRecords.values.map((record) => record.toJson()).toList(),
      ),
    );
    await preferences.setString(
      _contributionsKey,
      jsonEncode(_contributions.map((item) => item.toJson()).toList()),
    );
  }

  void _rollDailyWindowIfNeeded() {
    final today = _dayKey(DateTime.now());
    if (_dailyDate == today) return;

    _dailyRecords[_dailyDate] = _currentDailyRecord;
    setState(() {
      _dailyDate = today;
      _dailyOpeningValue = _fundValue;
      _todayContributions = 0;
    });
    unawaited(_savePortfolio());
    _scheduleDailyReset();
  }

  void _scheduleDailyReset() {
    _dailyResetTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dailyResetTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      _dailyRecords[_dailyDate] = _currentDailyRecord;
      setState(() {
        _dailyDate = _dayKey(DateTime.now());
        _dailyOpeningValue = _fundValue;
        _todayContributions = 0;
      });
      unawaited(_savePortfolio());
      _scheduleDailyReset();
    });
  }

  Future<double?> _askForAmount({
    required String title,
    required String actionLabel,
    double? initialValue,
    bool allowZero = false,
  }) {
    return showDialog<double>(
      context: context,
      builder: (context) => _AmountDialog(
        title: title,
        actionLabel: actionLabel,
        initialValue: initialValue,
        allowZero: allowZero,
      ),
    );
  }

  Future<void> _addContribution() async {
    final amount = await _askForAmount(
      title: 'Registrar aportación',
      actionLabel: 'Añadir',
    );
    if (amount == null) return;

    setState(() {
      _invested += amount;
      _fundValue += amount;
      _todayContributions += amount;
      _contributions.insert(
        0,
        Contribution(amount: amount, date: DateTime.now()),
      );
    });
    await _savePortfolio();
  }

  Future<void> _updateFundValue() async {
    final value = await _askForAmount(
      title: 'Actualizar valor del fondo',
      actionLabel: 'Guardar valor',
      initialValue: _fundValue,
      allowZero: true,
    );
    if (value == null) return;

    setState(() => _fundValue = value);
    await _savePortfolio();
  }

  Future<void> _resetPortfolio() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar fondo'),
        content: const Text(
          'Se borrarán el capital, el valor del fondo, las aportaciones y el historial diario del fondo seleccionado. Los demás fondos se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (shouldReset != true) return;

    setState(() {
      _invested = 0;
      _fundValue = 0;
      _dailyDate = _dayKey(DateTime.now());
      _dailyOpeningValue = 0;
      _todayContributions = 0;
      _contributions.clear();
      _dailyRecords.clear();
      _focusedDay = DateTime.now();
      _selectedDay = _focusedDay;
    });
    await _savePortfolio();
    _scheduleDailyReset();
  }

  Future<void> _deleteContribution(Contribution contribution) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar aportación'),
        content: Text(
          '¿Quieres eliminar ${_formatMoney(contribution.amount)} del registro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    final amount = contribution.amount;
    final contributionDate = _dayKey(contribution.date);
    setState(() {
      _contributions.remove(contribution);
      _invested -= amount;
      _fundValue -= amount;

      if (contributionDate == _dailyDate) {
        _todayContributions = math.max(0, _todayContributions - amount);
      } else if (contributionDate.compareTo(_dailyDate) < 0) {
        _dailyOpeningValue -= amount;
      }

      _dailyRecords.updateAll((date, record) {
        if (date == contributionDate) {
          return record.copyWith(
            closingValue: record.closingValue - amount,
            contributions: math.max(0, record.contributions - amount),
          );
        }
        if (date.compareTo(contributionDate) > 0) {
          return record.copyWith(
            openingValue: record.openingValue - amount,
            closingValue: record.closingValue - amount,
          );
        }
        return record;
      });
    });
    await _savePortfolio();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final gainIsPositive = _gain >= 0;
    final gainColor = gainIsPositive
        ? const Color(0xFF176B52)
        : const Color(0xFFB3433D);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: _buildHeader(),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      _buildOverviewPage(gainColor, gainIsPositive),
                      _buildChartPage(),
                      DistributionView(
                        key: ValueKey(_distributionRefresh),
                        funds: Map<String, String>.of(_funds),
                      ),
                      ProfileView(fundCount: _funds.length),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
            if (index == 2) _distributionRefresh++;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Principal',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart_rounded),
            label: 'Gráfico',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Fondos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPage(Color gainColor, bool gainIsPositive) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildFundSelector(),
              const SizedBox(height: 24),
              _buildBalancePanel(gainColor, gainIsPositive),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      label: 'Plusvalía',
                      value: _formatMoney(_gain),
                      detail: 'Ganancia acumulada',
                      icon: Icons.trending_up_rounded,
                      color: gainColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetric(
                      label: 'Capital aportado',
                      value: _formatMoney(_invested),
                      detail: 'Total invertido',
                      icon: Icons.savings_outlined,
                      color: const Color(0xFF525C58),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addContribution,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Aportar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _updateFundValue,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Actualizar'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionHeading('Calendario diario'),
              const SizedBox(height: 16),
              _buildDailyCalendar(),
              const SizedBox(height: 20),
              _buildActivityHeader(),
              const SizedBox(height: 10),
              _buildContributionList(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildChartPage() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeading('Plusvalía diaria'),
            const SizedBox(height: 16),
            _buildDailySummary(),
            const SizedBox(height: 24),
            SizedBox(
              height: math.max(280, constraints.maxHeight - 220),
              child: _buildHistoryChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/branding/inverto-icon.png',
            width: 50,
            height: 50,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INVERTO',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tu dinero, con perspectiva',
                style: TextStyle(color: Color(0xFF737D78), fontSize: 12),
              ),
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 430)
          Text(
            _formattedDate(DateTime.now()),
            style: const TextStyle(color: Color(0xFF737D78), fontSize: 12),
          ),
        IconButton(
          tooltip: 'Reiniciar datos',
          onPressed: _resetPortfolio,
          icon: const Icon(Icons.restart_alt_rounded),
          color: const Color(0xFF59645E),
        ),
      ],
    );
  }

  Widget _buildBalancePanel(Color gainColor, bool gainIsPositive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173F34), Color(0xFF0B2823)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2413392C),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Valor de tu fondo',
                  style: TextStyle(
                    color: Color(0xFFC0D8CC),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF9BD7B9),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatMoney(_fundValue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                letterSpacing: -1.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(
                gainIsPositive
                    ? Icons.north_east_rounded
                    : Icons.south_east_rounded,
                color: gainIsPositive
                    ? const Color(0xFF8EE0B8)
                    : const Color(0xFFFFA59D),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${_returnPercentage.toStringAsFixed(2).replaceAll('.', ',')}%',
                style: TextStyle(
                  color: gainIsPositive
                      ? const Color(0xFF8EE0B8)
                      : const Color(0xFFFFA59D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'sobre el capital aportado',
                  maxLines: 2,
                  style: TextStyle(color: Color(0xFFB6CEC4), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF69736E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                letterSpacing: -0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF8A938E), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary() {
    final isPositive = _dailyGain >= 0;
    final color = isPositive
        ? const Color(0xFF176B52)
        : const Color(0xFFB3433D);
    final formattedPercentage =
        '${_dailyReturnPercentage.toStringAsFixed(2).replaceAll('.', ',')}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFFEAF4EF)
                  : const Color(0xFFF9EDEC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isPositive
                  ? Icons.wb_sunny_outlined
                  : Icons.trending_down_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plusvalía de hoy',
                  style: TextStyle(
                    color: Color(0xFF26342E),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Rendimiento diario, sin aportaciones',
                  style: TextStyle(color: Color(0xFF89938D), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMoney(_dailyGain),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formattedPercentage,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Aportaciones recientes',
            style: TextStyle(
              color: Color(0xFF26342E),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${_contributions.length} ${_contributions.length == 1 ? 'aporte' : 'aportes'}',
          style: const TextStyle(color: Color(0xFF7C8680), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF26342E),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  List<DailyRecord> get _chartRecords {
    final records = _dailyRecords.values
        .where((record) => record.dateKey != _dailyDate)
        .toList();
    if (_dailyDate.isNotEmpty) {
      records.add(_currentDailyRecord);
    }
    records.sort((first, second) => first.dateKey.compareTo(second.dateKey));
    return records.length > 30 ? records.sublist(records.length - 30) : records;
  }

  Widget _buildHistoryChart() {
    final records = _chartRecords;
    if (records.isEmpty ||
        (records.length == 1 && records.first.closingValue == 0)) {
      return Container(
        width: double.infinity,
        height: 190,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7EAE5)),
        ),
        child: const Text(
          'Añade una valoración para ver la evolución.',
          style: TextStyle(color: Color(0xFF89938D), fontSize: 12),
        ),
      );
    }

    final spots = [
      for (var index = 0; index < records.length; index++)
        FlSpot(index.toDouble(), records[index].gain),
    ];
    final values = records.map((record) => record.gain);
    final lowestValue = values.reduce(math.min);
    final highestValue = values.reduce(math.max);
    final spread = highestValue - lowestValue;
    final padding = spread == 0
        ? math.max(highestValue.abs() * 0.05, 10.0)
        : spread * 0.12;
    final labelInterval = math.max(1, records.length ~/ 4).toDouble();
    final minY = math.min(lowestValue - padding, 0).toDouble();
    final maxY = math.max(highestValue + padding, 0).toDouble();
    final yAxisInterval = (maxY - minY) / 4;
    final yAxisFormat = NumberFormat.compactCurrency(
      locale: 'es_ES',
      symbol: '€',
      decimalDigits: 0,
    );

    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(10, 16, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAE5)),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, spots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: value == 0
                  ? const Color(0xFFCBD4CE)
                  : const Color(0xFFECEFEC),
              strokeWidth: value == 0 ? 1.5 : 1,
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: const Color(0xFFCBD4CE),
                strokeWidth: 1.5,
              ),
            ],
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                interval: yAxisInterval,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    yAxisFormat.format(value),
                    style: const TextStyle(
                      color: Color(0xFF89938D),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: labelInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= records.length) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.parse(records[index].dateKey);
                  return SideTitleWidget(
                    meta: meta,
                    space: 8,
                    child: Text(
                      DateFormat('d/M', 'es_ES').format(date),
                      style: const TextStyle(
                        color: Color(0xFF89938D),
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF176B52),
              barWidth: 2.5,
              dotData: FlDotData(show: spots.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0x20176B52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCalendar() {
    final selectedRecord = _recordForDate(_selectedDay);
    final selectedContributions = _contributionsForDate(_selectedDay);
    final contributionTotal = selectedContributions.fold<double>(
      0,
      (total, contribution) => total + contribution.amount,
    );
    final dailyGain = selectedRecord?.gain ?? 0;
    final gainColor = dailyGain >= 0
        ? const Color(0xFF176B52)
        : const Color(0xFFB3433D);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EAE5)),
      ),
      child: Column(
        children: [
          TableCalendar<DailyRecord>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            locale: 'es_ES',
            startingDayOfWeek: StartingDayOfWeek.monday,
            rowHeight: 52,
            daysOfWeekHeight: 32,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _calendarEventsForDate,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              headerPadding: const EdgeInsets.symmetric(vertical: 12),
              titleTextStyle: const TextStyle(
                color: Color(0xFF26342E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(4),
              defaultTextStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF26342E),
              ),
              weekendTextStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF7A8580),
              ),
              outsideDaysVisible: false,
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF176B52),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFEAF4EF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF176B52)),
              ),
              todayTextStyle: const TextStyle(color: Color(0xFF176B52)),
              markersMaxCount: 1,
            ),
            calendarBuilders: CalendarBuilders<DailyRecord>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: events.first.gain >= 0
                          ? const Color(0xFF176B52)
                          : const Color(0xFFB3433D),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE d MMMM', 'es_ES').format(_selectedDay),
                      style: const TextStyle(
                        color: Color(0xFF26342E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedRecord == null
                          ? selectedContributions.isEmpty
                                ? 'Sin valoración registrada'
                                : 'Aportaciones registradas'
                          : 'Variación diaria',
                      style: const TextStyle(
                        color: Color(0xFF89938D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedRecord != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMoney(selectedRecord.gain),
                      style: TextStyle(
                        color: gainColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${selectedRecord.returnPercentage.toStringAsFixed(2).replaceAll('.', ',')}%',
                      style: TextStyle(
                        color: gainColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (selectedContributions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFF176B52),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aportado este día',
                        style: TextStyle(
                          color: Color(0xFF26342E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        selectedContributions.length == 1
                            ? '1 aportación'
                            : '${selectedContributions.length} aportaciones',
                        style: const TextStyle(
                          color: Color(0xFF89938D),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatMoney(contributionTotal),
                  style: const TextStyle(
                    color: Color(0xFF176B52),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DailyRecord? _recordForDate(DateTime date) {
    final key = _dayKey(date);
    if (key == _dailyDate) return _currentDailyRecord;
    return _dailyRecords[key];
  }

  List<DailyRecord> _calendarEventsForDate(DateTime date) {
    final record = _recordForDate(date);
    if (record != null) return [record];

    final contributions = _contributionsForDate(date);
    if (contributions.isEmpty) return [];

    final total = contributions.fold<double>(
      0,
      (sum, contribution) => sum + contribution.amount,
    );
    return [
      DailyRecord(
        dateKey: _dayKey(date),
        openingValue: 0,
        closingValue: total,
        contributions: total,
      ),
    ];
  }

  List<Contribution> _contributionsForDate(DateTime date) {
    final key = _dayKey(date);
    return _contributions
        .where((contribution) => _dayKey(contribution.date) == key)
        .toList();
  }

  Widget _buildContributionList() {
    if (_contributions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7EAE5)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: Color(0xFF89938D),
              size: 25,
            ),
            SizedBox(height: 9),
            Text(
              'Aún no tienes aportaciones',
              style: TextStyle(
                color: Color(0xFF59645E),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Registra la primera para empezar tu seguimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF89938D), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAE5)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < _contributions.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 54, endIndent: 14),
            ListTile(
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF176B52),
                  size: 19,
                ),
              ),
              title: const Text(
                'Aportación al fondo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _formattedDate(_contributions[index].date),
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${_formatMoney(_contributions[index].amount)}',
                    style: const TextStyle(
                      color: Color(0xFF176B52),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar aportación',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _deleteContribution(_contributions[index]),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    color: const Color(0xFF7C8680),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMoney(double amount) =>
      '€ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formattedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.actionLabel,
    required this.allowZero,
    this.initialValue,
  });

  final String title;
  final String actionLabel;
  final bool allowZero;
  final double? initialValue;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toStringAsFixed(2).replaceAll('.', ',') ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(
      _controller.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount.isNaN || amount.isInfinite || amount < 0) {
      setState(() => _errorText = 'Introduce un importe válido.');
      return;
    }
    if (!widget.allowZero && amount == 0) {
      setState(() => _errorText = 'El importe debe ser mayor que cero.');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Importe',
          prefixText: '€ ',
          border: const OutlineInputBorder(),
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
