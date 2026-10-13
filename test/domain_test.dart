import 'package:flutter_test/flutter_test.dart';

import 'package:antrian_rs/domain/queue_domain.dart';

void main() {
  final issuedAt = DateTime.utc(2026, 10, 13, 8);

  QueueTicket ticket(QueueStatus status) => QueueTicket(
    id: 'ticket-1',
    number: 'A-001',
    service: 'general',
    priority: QueuePriority.normal,
    status: status,
    issuedAt: issuedAt,
    estimatedWait: const Duration(minutes: 15),
  );

  test('accepts valid status transition', () {
    expect(
      ticket(QueueStatus.issued).transitionTo(QueueStatus.waiting),
      isTrue,
    );
    expect(
      ticket(QueueStatus.waiting).transitionTo(QueueStatus.called),
      isTrue,
    );
    expect(ticket(QueueStatus.called).transitionTo(QueueStatus.served), isTrue);
  });

  test('rejects invalid status transition', () {
    expect(
      ticket(QueueStatus.issued).transitionTo(QueueStatus.served),
      isFalse,
    );
    expect(
      ticket(QueueStatus.served).transitionTo(QueueStatus.called),
      isFalse,
    );
  });

  test('requires reason for priority override', () {
    expect(
      () => PriorityOverride.create(
        actorId: 'nurse-1',
        reason: '',
        previous: QueuePriority.normal,
        next: QueuePriority.priority,
        occurredAt: issuedAt,
        eventId: 'event-1',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('serialises and deserialises ticket explicitly', () {
    final original = ticket(QueueStatus.waiting);
    final decoded = QueueTicket.fromJson(original.toJson());

    expect(decoded, equals(original));
    expect(decoded.number, 'A-001');
    expect(decoded.estimatedWait, const Duration(minutes: 15));
  });

  test('rejects malformed server response', () {
    expect(
      () => QueueTicket.fromJson({'id': 'x', 'status': 'UNKNOWN'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('serialises idempotency request', () {
    final request = IssueTicketRequest(
      clientRequestId: 'retry-1',
      serviceId: 'general',
      appointmentId: null,
    );
    expect(IssueTicketRequest.fromJson(request.toJson()), equals(request));
  });

  test('passes day-close reconciliation', () {
    final result = DayCloseReconciliation.check(
      issued: 10,
      served: 5,
      waiting: 2,
      noShow: 2,
      cancelled: 1,
    );
    expect(result.isBalanced, isTrue);
  });

  test('reports day-close reconciliation failure', () {
    final result = DayCloseReconciliation.check(
      issued: 10,
      served: 5,
      waiting: 3,
      noShow: 2,
      cancelled: 1,
    );
    expect(result.isBalanced, isFalse);
    expect(result.expectedIssued, 11);
  });

  test('no-show retains pseudonymous ticket number', () {
    final original = ticket(QueueStatus.called);
    final noShow = original.transitioned(QueueStatus.noShow);
    expect(noShow.number, original.number);
    expect(noShow.status, QueueStatus.noShow);
  });

  test('cancelled is not served', () {
    final result = DayCloseReconciliation.check(
      issued: 1,
      served: 0,
      waiting: 0,
      noShow: 0,
      cancelled: 1,
    );
    expect(result.isBalanced, isTrue);
    expect(result.served, isNot(1));
  });
}
