import 'package:flutter/material.dart';

import 'application/queue_application.dart';

void main() => runApp(const AntrianRsApp());

class AntrianRsApp extends StatelessWidget {
  const AntrianRsApp({super.key, this.controller});
  final QueueController? controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AntrianRS',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146C94)),
      useMaterial3: true,
    ),
    home: QueueHomePage(controller: controller),
  );
}

class QueueHomePage extends StatefulWidget {
  const QueueHomePage({super.key, this.controller, this.initialState});
  final QueueController? controller;
  final QueueScreenState? initialState;

  @override
  State<QueueHomePage> createState() => _QueueHomePageState();
}

class _QueueHomePageState extends State<QueueHomePage> {
  late QueueScreenState _state =
      widget.initialState ??
      const QueueScreenState(connection: ConnectionStateKind.disconnected);

  @override
  void initState() {
    super.initState();
    widget.controller?.onChanged = (state) {
      if (mounted) setState(() => _state = state);
    };
  }

  Future<void> _refresh() async {
    final controller = widget.controller;
    if (controller == null) return;
    await controller.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('AntrianRS'),
      actions: [
        IconButton(
          tooltip: 'Refresh board',
          onPressed: _state.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ConnectionBanner(state: _state),
          const SizedBox(height: 16),
          const _QueueHeader(),
          const SizedBox(height: 16),
          if (_state.isLoading) const _LoadingState(),
          if (_state.connection == ConnectionStateKind.disconnected)
            const _DisconnectedState(),
          if (_state.errorMessage != null) _ErrorState(onRetry: _refresh),
          if (_state.isEmpty) const _EmptyState(),
          if (_state.board.isNotEmpty) ...[
            _NowServingCard(item: _state.board.first),
            const SizedBox(height: 12),
            ..._state.board.skip(1).map((item) => _BoardTile(item: item)),
          ],
          const SizedBox(height: 20),
          const Text('OFFICER', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Aksi penerbitan dan override hanya berjalan melalui server. Client role hanya untuk visibilitas UX.',
          ),
        ],
      ),
    ),
  );
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state});
  final QueueScreenState state;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        state.connection == ConnectionStateKind.connected
            ? Icons.cloud_done
            : Icons.cloud_off,
      ),
      title: Text(switch (state.connection) {
        ConnectionStateKind.connected => 'Terhubung ke server',
        ConnectionStateKind.connecting => 'Menghubungkan...',
        _ => 'Server antrean tidak terhubung',
      }),
      subtitle: const Text('Server tetap source of truth untuk nomor antrean.'),
    ),
  );
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Poliklinik Umum',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 4),
      Text('Desk 01  •  Hari ini'),
    ],
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      title: Text('Memuat antrean...'),
      leading: CircularProgressIndicator(),
    ),
  );
}

class _DisconnectedState extends StatelessWidget {
  const _DisconnectedState();
  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      title: Text('Server antrean tidak terhubung.'),
      subtitle: Text('Data belum tersedia. Coba lagi saat API tersedia.'),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) =>
      const Card(child: ListTile(title: Text('Belum ada antrean.')));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: const Text('Gagal memuat antrean.'),
      trailing: TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
    ),
  );
}

class _NowServingCard extends StatelessWidget {
  const _NowServingCard({required this.item});
  final QueueBoardItem item;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      title: const Text('Nomor antrean'),
      subtitle: Text(item.service),
      trailing: Text(
        item.number,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.item});
  final QueueBoardItem item;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(item.number),
      subtitle: Text('${item.service} • ${item.waitLabel}'),
      trailing: Text(item.status.name.toUpperCase()),
    ),
  );
}
