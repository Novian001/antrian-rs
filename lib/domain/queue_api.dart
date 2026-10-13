import 'queue_domain.dart';

enum QueueApiErrorKind {
  disconnected,
  timeout,
  invalidResponse,
  unauthorized,
  forbidden,
  conflict,
  server,
}

class QueueApiError implements Exception {
  const QueueApiError(this.kind, this.message, {this.code});

  final QueueApiErrorKind kind;
  final String message;
  final String? code;

  @override
  String toString() => 'QueueApiError(${kind.name}): $message';
}

abstract interface class QueueApi {
  Future<QueueTicket> issueTicket(IssueTicketRequest request);
  Future<QueueTicket> getTicket(String ticketId);
  Future<List<QueueTicket>> getQueue(String serviceId);
  Future<QueueTicket> transitionTicket(String ticketId, QueueStatus next);
  Future<PriorityOverride> overridePriority(
    String ticketId,
    PriorityOverride override,
  );
  Future<DayCloseReconciliation> closeDay(String serviceId, DateTime day);
}
