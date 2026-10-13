import 'package:flutter_test/flutter_test.dart';
import 'package:antrian_rs/application/queue_application.dart';
import 'package:antrian_rs/domain/queue_api.dart';
import 'package:antrian_rs/domain/queue_domain.dart';

class RecordingApi implements QueueApi {
  RecordingApi({this.queue = const [], this.error});
  final List<QueueTicket> queue;
  final QueueApiError? error;
  String? lastRequestId;

  @override
  Future<QueueTicket> issueTicket(IssueTicketRequest request) async {
    lastRequestId = request.clientRequestId;
    if (error != null) throw error!;
    throw UnimplementedError();
  }

  @override
  Future<QueueTicket> getTicket(String ticketId) async =>
      throw UnimplementedError();
  @override
  Future<List<QueueTicket>> getQueue(String serviceId) async {
    if (error != null) throw error!;
    return queue;
  }

  @override
  Future<QueueTicket> transitionTicket(
    String ticketId,
    QueueStatus next,
  ) async => throw UnimplementedError();
  @override
  Future<PriorityOverride> overridePriority(
    String ticketId,
    PriorityOverride override,
  ) async => throw UnimplementedError();
  @override
  Future<DayCloseReconciliation> closeDay(
    String serviceId,
    DateTime day,
  ) async => throw UnimplementedError();
}

QueueTicket ticket({Duration? wait}) => QueueTicket(
  id: 't1',
  number: 'A-001',
  service: 'general',
  priority: QueuePriority.normal,
  status: QueueStatus.waiting,
  issuedAt: DateTime.utc(2026),
  estimatedWait: wait,
);

void main() {
  test('loading to success and empty states', () async {
    final controller = QueueController(
      RecordingApi(queue: [ticket()]),
      serviceId: 'general',
    );
    final future = controller.refresh();
    expect(controller.state.connection, ConnectionStateKind.connecting);
    await future;
    expect(controller.state.connection, ConnectionStateKind.connected);
    expect(controller.state.board.single.number, 'A-001');

    final empty = QueueController(RecordingApi(), serviceId: 'general');
    await empty.refresh();
    expect(empty.state.isEmpty, isTrue);
  });

  test('maps disconnected error and retry keeps request ID', () async {
    final api = RecordingApi(
      error: const QueueApiError(QueueApiErrorKind.disconnected, 'offline'),
    );
    final controller = QueueController(api, serviceId: 'general');
    await controller.refresh();
    expect(controller.state.connection, ConnectionStateKind.disconnected);
    final request = IssueTicketRequest(
      clientRequestId: 'retry-1',
      serviceId: 'general',
    );
    final result = await controller.issue(request);
    expect(result.kind, CommandResultKind.disconnected);
    expect(api.lastRequestId, 'retry-1');
  });

  test(
    'maps authorization, forbidden, conflict, and invalid response',
    () async {
      for (final pair in <QueueApiErrorKind, CommandResultKind>{
        QueueApiErrorKind.unauthorized: CommandResultKind.unauthorized,
        QueueApiErrorKind.forbidden: CommandResultKind.forbidden,
        QueueApiErrorKind.conflict: CommandResultKind.conflict,
        QueueApiErrorKind.invalidResponse: CommandResultKind.invalidResponse,
      }.entries) {
        final controller = QueueController(
          RecordingApi(error: QueueApiError(pair.key, 'safe')),
          serviceId: 'general',
        );
        final result = await controller.refresh();
        expect(result.kind, pair.value);
        expect(controller.state.errorMessage, 'Gagal memuat antrean.');
      }
    },
  );

  test('role visibility follows UX permissions only', () {
    expect(
      visibleCommands(UserRole.officer),
      contains(CommandName.issueTicket),
    );
    expect(
      visibleCommands(UserRole.triageNurse),
      contains(CommandName.assignPriority),
    );
    expect(
      visibleCommands(UserRole.supervisor),
      contains(CommandName.dayClose),
    );
    expect(
      visibleCommands(UserRole.patient),
      isNot(contains(CommandName.issueTicket)),
    );
    expect(
      visibleCommands(UserRole.admin),
      contains(CommandName.configureService),
    );
  });

  test('null estimated wait stays unavailable', () {
    expect(
      QueueBoardItem.fromTicket(ticket()).waitLabel,
      'Estimasi belum tersedia',
    );
  });
}
