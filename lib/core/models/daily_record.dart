class DailyRecord {
  const DailyRecord({
    required this.dateKey,
    required this.openingValue,
    required this.closingValue,
    required this.contributions,
  });

  final String dateKey;
  final double openingValue;
  final double closingValue;
  final double contributions;

  double get gain => closingValue - openingValue - contributions;
  double get returnPercentage =>
      openingValue == 0 ? 0 : gain / openingValue * 100;

  DailyRecord copyWith({
    double? openingValue,
    double? closingValue,
    double? contributions,
  }) => DailyRecord(
    dateKey: dateKey,
    openingValue: openingValue ?? this.openingValue,
    closingValue: closingValue ?? this.closingValue,
    contributions: contributions ?? this.contributions,
  );

  Map<String, Object> toJson() => {
    'date': dateKey,
    'opening': openingValue,
    'closing': closingValue,
    'contributions': contributions,
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    dateKey: json['date'] as String,
    openingValue: (json['opening'] as num).toDouble(),
    closingValue: (json['closing'] as num).toDouble(),
    contributions: (json['contributions'] as num).toDouble(),
  );
}
