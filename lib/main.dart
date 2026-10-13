import 'package:flutter/material.dart';

void main() => runApp(const AntrianRsApp());

class AntrianRsApp extends StatelessWidget {
  const AntrianRsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AntrianRS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF146C94),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const QueueHomePage(),
    );
  }
}

class QueueHomePage extends StatelessWidget {
  const QueueHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AntrianRS'),
        actions: [
          IconButton(
            tooltip: 'Refresh board',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _ConnectionBanner(),
            SizedBox(height: 20),
            _QueueHeader(),
            SizedBox(height: 16),
            _NowServingCard(),
            SizedBox(height: 16),
            _QueueSummary(),
            SizedBox(height: 24),
            Text(
              'Petugas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Mode baca saja sampai server terhubung. Penerbitan nomor dan override wajib melalui API server.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const ListTile(
        leading: Icon(Icons.cloud_off_outlined),
        title: Text('Server belum terhubung'),
        subtitle: Text(
          'Data antrean akan muncul setelah koneksi API tersedia.',
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Poliklinik Umum',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Desk 01  •  Hari ini'),
            ],
          ),
        ),
        Chip(label: Text('OFFICER')),
      ],
    );
  }
}

class _NowServingCard extends StatelessWidget {
  const _NowServingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sedang dipanggil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '—',
              style: Theme.of(context).textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text('Belum ada panggilan dari server.'),
          ],
        ),
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _Metric(label: 'Menunggu', value: '—'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _Metric(label: 'Estimasi tunggu', value: '—'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
