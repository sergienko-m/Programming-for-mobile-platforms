class BankRate {
  const BankRate({
    required this.bank,
    required this.buy,
    required this.sell,
    required this.updatedAt,
  });

  final String bank;
  final double buy;
  final double sell;
  final DateTime updatedAt;

  BankRate copyWith({double? buy, double? sell, DateTime? updatedAt}) {
    return BankRate(
      bank: bank,
      buy: buy ?? this.buy,
      sell: sell ?? this.sell,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ExchangeQuote {
  const ExchangeQuote({required this.value, required this.changePercent});

  final double value;
  final double changePercent;
}

class RateLoadResult {
  const RateLoadResult({required this.rates, required this.unavailableBanks, required this.elapsed, required this.parallel});

  final List<BankRate> rates;
  final List<String> unavailableBanks;
  final Duration elapsed;
  final bool parallel;
}
