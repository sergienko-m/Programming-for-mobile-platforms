import 'package:flutter/material.dart';

import '../models/bank_rate.dart';
import '../services/fake_rates_service.dart';

class RatesScreen extends StatefulWidget {
  const RatesScreen({required this.service, super.key});

  final FakeRatesService service;

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  late Future<RateLoadResult> _ratesFuture;
  late final Stream<ExchangeQuote> _exchangeStream;
  BankRate? _fastest;
  ExchangeQuote? _latestQuote;

  @override
  void initState() {
    super.initState();
    _ratesFuture = widget.service.loadAllRates();
    _exchangeStream = widget.service.exchangeStream;
  }

  Future<void> _reload() async {
    setState(() => _ratesFuture = widget.service.loadAllRates());
    try {
      await _ratesFuture;
      if (!mounted) return;
    } on Object {
      // FutureBuilder відобразить помилку, якщо сервіс повертає її назовні.
    }
  }

  Future<void> _findFastest() async {
    try {
      final result = await widget.service.fetchFastest();
      if (!mounted) return;
      setState(() => _fastest = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Найшвидше відповів ${result.bank}')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Агрегатор курсів'),
        actions: [
          IconButton(onPressed: _reload, tooltip: 'Оновити', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: StreamBuilder<ExchangeQuote>(
        stream: _exchangeStream,
        builder: (context, quoteSnapshot) {
          if (quoteSnapshot.hasData) _latestQuote = quoteSnapshot.data;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _ExchangeCard(quote: _latestQuote),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _findFastest,
                  icon: const Icon(Icons.speed),
                  label: const Text('Найшвидше джерело'),
                ),
                if (_fastest != null) ...[
                  const SizedBox(height: 8),
                  Text('Остання найшвидша відповідь: ${_fastest!.bank}', style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 20),
                Text('Курси банків', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FutureBuilder<RateLoadResult>(
                  future: _ratesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _LoadingCard();
                    }
                    if (snapshot.hasError) {
                      return _ErrorCard(onRetry: _reload);
                    }
                    final result = snapshot.data;
                    if (result == null || result.rates.isEmpty) {
                      return _EmptyCard(onRetry: _reload);
                    }
                    return _RatesContent(result: result);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExchangeCard extends StatelessWidget {
  const _ExchangeCard({required this.quote});
  final ExchangeQuote? quote;

  @override
  Widget build(BuildContext context) {
    final change = quote?.changePercent ?? 0;
    final rising = change >= 0;
    return Card(
      color: change.abs() > 0.005 ? (rising ? Colors.green.shade50 : Colors.red.shade50) : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(rising ? Icons.trending_up : Icons.trending_down)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Біржовий курс USD/UAH'),
              Text(quote == null ? 'Очікування оновлення…' : quote!.value.toStringAsFixed(2), style: Theme.of(context).textTheme.headlineSmall),
            ])),
            if (quote != null) Text('${rising ? '+' : ''}${(change * 100).toStringAsFixed(2)}%', style: TextStyle(color: rising ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RatesContent extends StatelessWidget {
  const _RatesContent({required this.result});
  final RateLoadResult result;

  @override
  Widget build(BuildContext context) {
    final bestBuy = result.rates.reduce((a, b) => a.buy > b.buy ? a : b);
    final bestSell = result.rates.reduce((a, b) => a.sell < b.sell ? a : b);
    return Column(children: [
      Card(child: ListTile(leading: const Icon(Icons.insights), title: const Text('Найвигідніші пропозиції'), subtitle: Text('Купівля: ${bestBuy.bank} (${bestBuy.buy.toStringAsFixed(2)}) · Продаж: ${bestSell.bank} (${bestSell.sell.toStringAsFixed(2)})'))),
      ...result.rates.map((rate) => Card(child: ListTile(leading: const Icon(Icons.account_balance), title: Text(rate.bank), subtitle: Text('Оновлено: ${rate.updatedAt.hour.toString().padLeft(2, '0')}:${rate.updatedAt.minute.toString().padLeft(2, '0')}'), trailing: Text('Купівля ${rate.buy.toStringAsFixed(2)}\nПродаж ${rate.sell.toStringAsFixed(2)}', textAlign: TextAlign.right)))),
      ...result.unavailableBanks.map((bank) => Card(child: ListTile(leading: const Icon(Icons.cloud_off, color: Colors.orange), title: Text(bank), subtitle: const Text('Джерело недоступне після 3 спроб'), trailing: const Text('Недоступний')))),
      Padding(padding: const EdgeInsets.only(top: 8), child: Text('Паралельне завантаження: ${result.elapsed.inMilliseconds} мс', style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Завантаження курсів…')]))));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('Не вдалося завантажити курси'), trailing: TextButton(onPressed: onRetry, child: const Text('Повторити'))));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.inbox_outlined), title: const Text('Немає доступних даних'), trailing: TextButton(onPressed: onRetry, child: const Text('Повторити'))));
}
