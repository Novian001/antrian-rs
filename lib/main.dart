import 'package:flutter/material.dart';

import 'application/queue_application.dart';
import 'domain/queue_domain.dart';

void main() => runApp(const AntrianRsApp());

class AntrianRsApp extends StatelessWidget {
  const AntrianRsApp({
    super.key,
    this.controller,
    this.role = UserRole.officer,
    this.initialState,
  });
  final QueueController? controller;
  final UserRole role;
  final QueueScreenState? initialState;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AntrianRS',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF146C94)),
      useMaterial3: true,
    ),
    home: QueueHomePage(
      controller: controller,
      role: role,
      initialState: initialState,
    ),
  );
}

class QueueHomePage extends StatefulWidget {
  const QueueHomePage({
    super.key,
    this.controller,
    this.role = UserRole.officer,
    this.initialState,
  });
  final QueueController? controller;
  final UserRole role;
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

  Future<void> _refresh() async => widget.controller?.refresh();

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
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionBanner(state: _state),
          const SizedBox(height: 16),
          Text(
            '${widget.role.name.toUpperCase()} · Queue board',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_state.isLoading) const _LoadingState(),
          if (_state.connection == ConnectionStateKind.disconnected)
            const _DisconnectedState(),
          if (_state.errorMessage != null) _ErrorState(onRetry: _refresh),
          if (_state.isEmpty) const _EmptyState(),
          if (_state.currentTicket != null) ...[
            _CurrentTicketCard(item: _state.currentTicket!),
            const SizedBox(height: 12),
          ],
          if (_state.board.isNotEmpty) _BoardSection(items: _state.board),
          if (_state.reconciliation != null) ...[
            const SizedBox(height: 16),
            _ReconciliationCard(report: _state.reconciliation!),
          ],
          if (_state.audit.isNotEmpty) ...[
            const SizedBox(height: 16),
            _AuditSection(events: _state.audit),
          ],
          if (widget.role == UserRole.patient && _state.currentTicket == null)
            const _NoCurrentTicket(),
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
      subtitle: const Text(
        'Server tetap source of truth. Data pasien tidak ditampilkan.',
      ),
    ),
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

class _NoCurrentTicket extends StatelessWidget {
  const _NoCurrentTicket();
  @override
  Widget build(BuildContext context) =>
      const Card(child: ListTile(title: Text('Belum ada tiket aktif.')));
}

class _CurrentTicketCard extends StatelessWidget {
  const _CurrentTicketCard({required this.item});
  final QueueBoardItem item;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current ticket',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            item.number,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          Text(item.service),
          _TicketMeta(item: item),
        ],
      ),
    ),
  );
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({required this.items});
  final List<QueueBoardItem> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Live queue board',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      ...items.map((item) => _BoardTile(item: item)),
    ],
  );
}

class _TicketMeta extends StatelessWidget {
  const _TicketMeta({required this.item});
  final QueueBoardItem item;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      Chip(
        avatar: const Icon(Icons.flag, size: 16),
        label: Text(
          item.priority == QueuePriority.priority ? 'PRIORITY' : 'NORMAL',
        ),
      ),
      Chip(label: Text(item.status.name.toUpperCase())),
      Chip(
        avatar: const Icon(Icons.schedule, size: 16),
        label: Text(item.waitLabel),
      ),
    ],
  );
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.item});
  final QueueBoardItem item;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(item.service),
            ],
          ),
          const SizedBox(height: 4),
          _TicketMeta(item: item),
        ],
      ),
    ),
  );
}

class _ReconciliationCard extends StatelessWidget {
  const _ReconciliationCard({required this.report});
  final ReconciliationPresentation report;
  @override
  Widget build(BuildContext context) {
    final value = report.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Day-close reconciliation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _CountGrid(
              values: {
                'Issued': value.issued,
                'Served': value.served,
                'Waiting': value.waiting,
                'No-show': value.noShow,
                'Cancelled': value.cancelled,
                'Expected issued': value.expectedIssued,
              },
            ),
            const SizedBox(height: 10),
            Text(
              report.statusLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: value.isBalanced
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountGrid extends StatelessWidget {
  const _CountGrid({required this.values});
  final Map<String, int> values;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values.entries
        .map(
          (entry) => SizedBox(
            width: 135,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _AuditSection extends StatelessWidget {
  const _AuditSection({required this.events});
  final List<AuditPresentation> events;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audit events',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...events
              .where((event) => event.isValid)
              .map(
                (event) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long),
                  title: Text(event.typeLabel),
                  subtitle: Text(
                    '${event.actorLabel} · ${event.event.occurredAt.toIso8601String()}\nTicket ${event.event.ticketId} · Event ${event.event.id}',
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}
