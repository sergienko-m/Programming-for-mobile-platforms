import 'dart:async';
import 'dart:math';

import '../models/bank_rate.dart';

class FakeRatesService {
  FakeRatesService({this.failureRate = 0.15, Random? random}) : _random = random ?? Random();

  final double failureRate;
  final Random _random;
  final StreamController<double> _exchangeController = StreamController<double>.broadcast();
  Timer? _exchangeTimer;
  double _exchangeValue = 40.15;
  double _lastEmitted = 40.15;

  static const _banks = <String>['Monobank', 'PrivatBank', 'PUMB'];
  static const _baseBuy = <double>[40.02, 39.98, 40.08];
  static const _baseSell = <double>[40.34, 40.31, 40.39];

  Future<BankRate> fetchBankRate(int index) async {
    final delay = 450 + _random.nextInt(850);
    await Future<void>.delayed(Duration(milliseconds: delay));
    if (_random.nextDouble() < failureRate) {
      throw StateError('${_banks[index]} тимчасово недоступний');
    }
    final drift = (_random.nextDouble() - 0.5) * 0.12;
    return BankRate(
      bank: _banks[index],
      buy: _baseBuy[index] + drift,
      sell: _baseSell[index] + drift,
      updatedAt: DateTime.now(),
    );
  }

  Future<BankRate> fetchWithRetry(int index, {int attempts = 3}) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await fetchBankRate(index).timeout(const Duration(seconds: 3));
      } on Object catch (error) {
        lastError = error;
        if (attempt < attempts - 1) {
          await Future<void>.delayed(Duration(milliseconds: 250 * pow(2, attempt).toInt()));
        }
      }
    }
    throw lastError ?? StateError('Невідома помилка');
  }

  Future<RateLoadResult> loadAllRates() async {
    final stopwatch = Stopwatch()..start();
    final results = await Future.wait<BankRate?>(
      List.generate(_banks.length, (index) async {
        try {
          return await fetchWithRetry(index);
        } on Object {
          return null;
        }
      }),
      eagerError: false,
    );
    stopwatch.stop();
    final rates = results.whereType<BankRate>().toList();
    if (rates.isEmpty) {
      throw StateError('Усі банки тимчасово недоступні');
    }
    return RateLoadResult(
      rates: rates,
      unavailableBanks: [
        for (var index = 0; index < results.length; index++)
          if (results[index] == null) _banks[index],
      ],
      elapsed: stopwatch.elapsed,
      parallel: true,
    );
  }

  Future<BankRate> fetchFastest() async {
    return Future.any(List.generate(_banks.length, fetchWithRetry));
  }

  Stream<ExchangeQuote> get exchangeStream {
    _exchangeTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      _exchangeValue += (_random.nextDouble() - 0.5) * 0.18;
      if (!_exchangeController.isClosed) {
        _exchangeController.add(_exchangeValue);
      }
    });
    return _exchangeController.stream
        .map((value) {
          // Відсоток зміни відносно останнього показаного значення.
          final change = (value - _lastEmitted) / _lastEmitted;
          if (change.abs() > 0.005) _lastEmitted = value;
          return ExchangeQuote(value: value, changePercent: change);
        })
        .where((quote) => quote.changePercent.abs() > 0.005);
  }

  void dispose() {
    _exchangeTimer?.cancel();
    _exchangeTimer = null;
    _exchangeController.close();
  }
}
