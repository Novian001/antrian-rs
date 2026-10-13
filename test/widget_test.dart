import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antrian_rs/application/queue_application.dart';
import 'package:antrian_rs/domain/queue_domain.dart';
import 'package:antrian_rs/main.dart';

void main() {
  testWidgets('shows disconnected state', (tester) async {
    await tester.pumpWidget(const AntrianRsApp());
    expect(find.text('Server antrean tidak terhubung'), findsWidgets);
  });

  testWidgets('shows role context and retry-ready shell', (tester) async {
    await tester.pumpWidget(const AntrianRsApp());
    expect(find.text('OFFICER'), findsOneWidget);
    expect(
      find.text(
        'Aksi penerbitan dan override hanya berjalan melalui server. Client role hanya untuk visibilitas UX.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Refresh board'), findsOneWidget);
  });

  testWidgets('renders board item without fake wait estimate', (tester) async {
    const state = QueueScreenState(
      connection: ConnectionStateKind.connected,
      board: [
        QueueBoardItem(
          number: 'A-001',
          service: 'general',
          priority: QueuePriority.normal,
          status: QueueStatus.waiting,
          waitLabel: 'Estimasi belum tersedia',
        ),
        QueueBoardItem(
          number: 'A-002',
          service: 'general',
          priority: QueuePriority.normal,
          status: QueueStatus.waiting,
          waitLabel: 'Estimasi belum tersedia',
        ),
      ],
    );
    await tester.pumpWidget(const AntrianRsApp());
    await tester.pumpWidget(
      const MaterialApp(home: QueueHomePage(initialState: state)),
    );
    expect(find.text('A-001'), findsOneWidget);
    expect(find.text('A-002'), findsOneWidget);
    expect(find.text('5 menit'), findsNothing);
  });
}
