import 'package:shared_preferences/shared_preferences.dart';

/// Reads the same SharedPreferences keys used by earlier Inverto versions.
/// Keeping these keys stable preserves existing portfolios across app updates.
class PortfolioStorageService {
  const PortfolioStorageService();

  Future<Map<String, ({double invested, double value})>> loadFundValues(
    Map<String, String> funds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final id in funds.keys)
        id: (
          invested: prefs.getDouble(_key(id, 'invested_total')) ?? 0,
          value: prefs.getDouble(_key(id, 'fund_value')) ?? 0,
        ),
    };
  }

  String _key(String id, String key) =>
      id == 'default' ? key : 'fund_${id}_$key';
}
