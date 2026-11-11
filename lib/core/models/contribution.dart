class Contribution {
  const Contribution({required this.amount, required this.date});

  final double amount;
  final DateTime date;

  Map<String, Object> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
  };

  factory Contribution.fromJson(Map<String, dynamic> json) => Contribution(
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
  );
}
