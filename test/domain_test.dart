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

  test('covers every valid transition and preserves ticket identity', () {
    final valid = <QueueStatus, Set<QueueStatus>>{
      QueueStatus.issued: {QueueStatus.waiting, QueueStatus.cancelled},
      QueueStatus.waiting: {QueueStatus.called, QueueStatus.cancelled},
      QueueStatus.called: {
        QueueStatus.served,
        QueueStatus.noShow,
        QueueStatus.cancelled,
      },
      QueueStatus.noShow: {QueueStatus.called, QueueStatus.cancelled},
    };
    for (final entry in valid.entries) {
      for (final next in entry.value) {
        final result = ticket(entry.key).transitioned(next, at: issuedAt);
        expect(result.id, 'ticket-1');
        expect(result.number, 'A-001');
      }
    }
    for (final terminal in [QueueStatus.served, QueueStatus.cancelled]) {
      for (final next in QueueStatus.values) {
        expect(ticket(terminal).transitionTo(next), isFalse);
      }
    }
  });

  test('rejects every invalid transition', () {
    final valid = <QueueStatus, Set<QueueStatus>>{
      QueueStatus.issued: {QueueStatus.waiting, QueueStatus.cancelled},
      QueueStatus.waiting: {QueueStatus.called, QueueStatus.cancelled},
      QueueStatus.called: {
        QueueStatus.served,
        QueueStatus.noShow,
        QueueStatus.cancelled,
      },
      QueueStatus.noShow: {QueueStatus.called, QueueStatus.cancelled},
    };
    for (final status in QueueStatus.values) {
      for (final next in QueueStatus.values) {
        if (!(valid[status] ?? {}).contains(next)) {
          expect(ticket(status).transitionTo(next), isFalse);
          expect(() => ticket(status).transitioned(next), throwsStateError);
        }
      }
    }
  });

  test('no-show can return to called without changing ticket number', () {
    final result = ticket(QueueStatus.called)
        .transitioned(QueueStatus.noShow, at: issuedAt)
        .transitioned(QueueStatus.called, at: issuedAt);
    expect(result.number, 'A-001');
    expect(result.status, QueueStatus.called);
  });

  test('rejects invalid priority override fields and timestamp', () {
    final base = <String, Object?>{
      'actor_id': 'actor',
      'reason': 'reason',
      'previous_priority': 'NORMAL',
      'new_priority': 'PRIORITY',
      'occurred_at': issuedAt.toIso8601String(),
      'event_id': 'event',
    };
    for (final field in ['actor_id', 'reason', 'event_id']) {
      final payload = {...base, field: ''};
      expect(() => PriorityOverride.fromJson(payload), throwsArgumentError);
    }
    expect(
      () => PriorityOverride.fromJson({...base, 'occurred_at': 'bad'}),
      throwsFormatException,
    );
    expect(
      () => PriorityOverride.fromJson({...base, 'new_priority': 'URGENT'}),
      throwsFormatException,
    );
  });

  test('rejects negative and invalid reconciliation values', () {
    expect(
      () => DayCloseReconciliation.check(
        issued: -1,
        served: 0,
        waiting: 0,
        noShow: 0,
        cancelled: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => DayCloseReconciliation.fromJson({
        'issued': 1,
        'served': '1',
        'waiting': 0,
        'no_show': 0,
        'cancelled': 0,
      }),
      throwsFormatException,
    );
  });

  test('rejects negative estimated wait and malformed event metadata', () {
    final json = ticket(QueueStatus.waiting).toJson();
    expect(
      () => QueueTicket.fromJson({...json, 'estimated_wait_seconds': -1}),
      throwsArgumentError,
    );
    expect(
      () => QueueEvent.fromJson({
        'id': 'event',
        'ticket_id': 'ticket-1',
        'type': 'CALLED',
        'occurred_at': issuedAt.toIso8601String(),
        'actor_id': 42,
        'metadata': [],
      }),
      throwsFormatException,
    );
  });

  test('rejects missing and null required request fields', () {
    expect(
      () => IssueTicketRequest.fromJson({'service_id': 'general'}),
      throwsFormatException,
    );
    expect(
      () => IssueTicketRequest.fromJson({
        'client_request_id': null,
        'service_id': 'general',
      }),
      throwsFormatException,
    );
  });

  test('reconciliation keeps server counters and expected total readable', () {
    for (final values in [
      [0, 0, 0, 0, 0],
      [1, 0, 1, 0, 0],
      [1, 1, 0, 0, 0],
      [1, 0, 0, 0, 1],
      [1, 0, 0, 1, 0],
      [9, 2, 3, 1, 1],
      [8, 2, 3, 1, 1],
      [10, 2, 3, 1, 1],
    ]) {
      final result = DayCloseReconciliation.check(
        issued: values[0],
        served: values[1],
        waiting: values[2],
        noShow: values[3],
        cancelled: values[4],
      );
      expect(
        result.expectedIssued,
        values[1] + values[2] + values[3] + values[4],
      );
      expect(result.issued, values[0]);
    }
  });
}
