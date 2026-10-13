import '../domain/queue_api.dart';
import '../domain/queue_domain.dart';

/// Future transport seam. No HTTP package or production implementation yet.
abstract interface class QueueTransport {
  Future<Map<String, Object?>> send(
    String operation,
    Map<String, Object?> payload,
  );
}

class QueueHttpClient implements QueueApi {
  const QueueHttpClient(this.transport);
  final QueueTransport transport;

  @override
  Future<QueueTicket> issueTicket(IssueTicketRequest request) async =>
      QueueTicket.fromJson(await _call('issue_ticket', request.toJson()));
  @override
  Future<QueueTicket> getTicket(String ticketId) async =>
      QueueTicket.fromJson(await _call('get_ticket', {'ticket_id': ticketId}));
  @override
  Future<List<QueueTicket>> getQueue(String serviceId) async {
    final body = await _call('get_queue', {'service_id': serviceId});
    final raw = body['tickets'];
    if (raw is! List) throw const FormatException('Invalid tickets');
    return raw
        .map((item) {
          if (item is! Map<String, Object?>)
            throw const FormatException('Invalid ticket');
          return QueueTicket.fromJson(item);
        })
        .toList(growable: false);
  }

  @override
  Future<QueueTicket> transitionTicket(
    String ticketId,
    QueueStatus next,
  ) async => QueueTicket.fromJson(
    await _call('transition_ticket', {
      'ticket_id': ticketId,
      'status': next.name.toUpperCase(),
    }),
  );
  @override
  Future<PriorityOverride> overridePriority(
    String ticketId,
    PriorityOverride override,
  ) async {
    final body = await _call('override_priority', {
      'ticket_id': ticketId,
      ...override.toJson(),
    });
    return PriorityOverride.fromJson(body);
  }

  @override
  Future<DayCloseReconciliation> closeDay(
    String serviceId,
    DateTime day,
  ) async {
    final body = await _call('close_day', {
      'service_id': serviceId,
      'day': day.toUtc().toIso8601String(),
    });
    return DayCloseReconciliation.fromJson(body);
  }

  Future<Map<String, Object?>> _call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    try {
      return await transport.send(operation, payload);
    } on QueueApiError {
      rethrow;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw QueueApiError(QueueApiErrorKind.server, 'Transport failed: $error');
    }
  }
}
