import 'package:flutter/material.dart';
import 'screens/rates_screen.dart';
import 'services/fake_rates_service.dart';

void main() {
  runApp(const RatesApp());
}

class RatesApp extends StatefulWidget {
  const RatesApp({super.key});

  @override
  State<RatesApp> createState() => _RatesAppState();
}

class _RatesAppState extends State<RatesApp> {
  late final FakeRatesService _service;

  @override
  void initState() {
    super.initState();
    _service = FakeRatesService(failureRate: 0.15);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Курси валют',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2457a6)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff5f7fb),
      ),
      home: RatesScreen(service: _service),
    );
  }
}
