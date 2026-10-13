enum QueueStatus { issued, waiting, called, served, noShow, cancelled }

enum QueuePriority { normal, priority }

enum QueueEventType {
  issued,
  called,
  served,
  noShow,
  cancelled,
  priorityOverride,
  dayClose,
}

String _enumName(Object value) => value.toString().split('.').last;

T _required<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! T) throw FormatException('Missing or invalid $key');
  return value;
}

DateTime _date(Map<String, Object?> json, String key) {
  final raw = _required<String>(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) throw FormatException('Invalid $key');
  return parsed.toUtc();
}

String _wire(Object value) => _enumName(value).toUpperCase();

T _parseEnum<T extends Enum>(String raw, Iterable<T> values, String key) {
  for (final value in values) {
    if (_wire(value) == raw) return value;
  }
  throw FormatException('Invalid $key');
}

class QueueTicket {
  const QueueTicket({
    required this.id,
    required this.number,
    required this.service,
    required this.priority,
    required this.status,
    required this.issuedAt,
    this.calledAt,
    this.servedAt,
    this.noShowAt,
    this.cancelledAt,
    this.estimatedWait,
  });

  final String id;
  final String number;
  final String service;
  final QueuePriority priority;
  final QueueStatus status;
  final DateTime issuedAt;
  final DateTime? calledAt;
  final DateTime? servedAt;
  final DateTime? noShowAt;
  final DateTime? cancelledAt;
  final Duration? estimatedWait;

  bool transitionTo(QueueStatus next) =>
      _validTransitions[status]!.contains(next);

  QueueTicket transitioned(QueueStatus next, {DateTime? at}) {
    if (!transitionTo(next)) {
      throw StateError('Invalid transition ${_wire(status)} to ${_wire(next)}');
    }
    final timestamp = (at ?? DateTime.now()).toUtc();
    return QueueTicket(
      id: id,
      number: number,
      service: service,
      priority: priority,
      status: next,
      issuedAt: issuedAt,
      calledAt: next == QueueStatus.called ? timestamp : calledAt,
      servedAt: next == QueueStatus.served ? timestamp : servedAt,
      noShowAt: next == QueueStatus.noShow ? timestamp : noShowAt,
      cancelledAt: next == QueueStatus.cancelled ? timestamp : cancelledAt,
      estimatedWait: estimatedWait,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'service': service,
    'priority': _wire(priority),
    'status': _wire(status),
    'issued_at': issuedAt.toUtc().toIso8601String(),
    'called_at': calledAt?.toUtc().toIso8601String(),
    'served_at': servedAt?.toUtc().toIso8601String(),
    'no_show_at': noShowAt?.toUtc().toIso8601String(),
    'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
    'estimated_wait_seconds': estimatedWait?.inSeconds,
  };

  factory QueueTicket.fromJson(Map<String, Object?> json) {
    final status = _parseEnum(
      _required<String>(json, 'status'),
      QueueStatus.values,
      'status',
    );
    final estimated = json['estimated_wait_seconds'];
    if (estimated != null && estimated is! int) {
      throw FormatException('Invalid estimated_wait_seconds');
    }
    return QueueTicket(
      id: _required<String>(json, 'id'),
      number: _required<String>(json, 'number'),
      service: _required<String>(json, 'service'),
      priority: _parseEnum(
        _required<String>(json, 'priority'),
        QueuePriority.values,
        'priority',
      ),
      status: status,
      issuedAt: _date(json, 'issued_at'),
      calledAt: json['called_at'] == null ? null : _date(json, 'called_at'),
      servedAt: json['served_at'] == null ? null : _date(json, 'served_at'),
      noShowAt: json['no_show_at'] == null ? null : _date(json, 'no_show_at'),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : _date(json, 'cancelled_at'),
      estimatedWait: estimated == null
          ? null
          : Duration(seconds: estimated as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QueueTicket &&
      other.id == id &&
      other.number == number &&
      other.service == service &&
      other.priority == priority &&
      other.status == status &&
      other.issuedAt == issuedAt &&
      other.calledAt == calledAt &&
      other.servedAt == servedAt &&
      other.noShowAt == noShowAt &&
      other.cancelledAt == cancelledAt &&
      other.estimatedWait == estimatedWait;

  @override
  int get hashCode => Object.hash(
    id,
    number,
    service,
    priority,
    status,
    issuedAt,
    calledAt,
    servedAt,
    noShowAt,
    cancelledAt,
    estimatedWait,
  );
}

const _validTransitions = <QueueStatus, Set<QueueStatus>>{
  QueueStatus.issued: {QueueStatus.waiting, QueueStatus.cancelled},
  QueueStatus.waiting: {QueueStatus.called, QueueStatus.cancelled},
  QueueStatus.called: {
    QueueStatus.served,
    QueueStatus.noShow,
    QueueStatus.cancelled,
  },
  QueueStatus.served: <QueueStatus>{},
  QueueStatus.noShow: {QueueStatus.called, QueueStatus.cancelled},
  QueueStatus.cancelled: <QueueStatus>{},
};

class PriorityOverride {
  const PriorityOverride({
    required this.actorId,
    required this.reason,
    required this.previous,
    required this.next,
    required this.occurredAt,
    required this.eventId,
  });

  factory PriorityOverride.create({
    required String actorId,
    required String reason,
    required QueuePriority previous,
    required QueuePriority next,
    required DateTime occurredAt,
    required String eventId,
  }) {
    if (reason.trim().isEmpty)
      throw ArgumentError.value(reason, 'reason', 'must not be empty');
    if (actorId.trim().isEmpty || eventId.trim().isEmpty)
      throw ArgumentError('actorId and eventId are required');
    return PriorityOverride(
      actorId: actorId,
      reason: reason.trim(),
      previous: previous,
      next: next,
      occurredAt: occurredAt.toUtc(),
      eventId: eventId,
    );
  }

  final String actorId;
  final String reason;
  final QueuePriority previous;
  final QueuePriority next;
  final DateTime occurredAt;
  final String eventId;

  factory PriorityOverride.fromJson(Map<String, Object?> json) =>
      PriorityOverride.create(
        actorId: _required<String>(json, 'actor_id'),
        reason: _required<String>(json, 'reason'),
        previous: _parseEnum(
          _required<String>(json, 'previous_priority'),
          QueuePriority.values,
          'previous_priority',
        ),
        next: _parseEnum(
          _required<String>(json, 'new_priority'),
          QueuePriority.values,
          'new_priority',
        ),
        occurredAt: _date(json, 'occurred_at'),
        eventId: _required<String>(json, 'event_id'),
      );

  Map<String, Object?> toJson() => {
    'actor_id': actorId,
    'reason': reason,
    'previous_priority': _wire(previous),
    'new_priority': _wire(next),
    'occurred_at': occurredAt.toIso8601String(),
    'event_id': eventId,
  };
}

class QueueEvent {
  const QueueEvent({
    required this.id,
    required this.ticketId,
    required this.type,
    required this.occurredAt,
    this.actorId,
    this.metadata = const {},
  });

  final String id;
  final String ticketId;
  final QueueEventType type;
  final DateTime occurredAt;
  final String? actorId;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'ticket_id': ticketId,
    'type': _wire(type),
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'actor_id': actorId,
    'metadata': metadata,
  };

  factory QueueEvent.fromJson(Map<String, Object?> json) {
    final metadata = json['metadata'];
    if (metadata != null && metadata is! Map<String, Object?>) {
      throw FormatException('Invalid metadata');
    }
    return QueueEvent(
      id: _required<String>(json, 'id'),
      ticketId: _required<String>(json, 'ticket_id'),
      type: _parseEnum(
        _required<String>(json, 'type'),
        QueueEventType.values,
        'type',
      ),
      occurredAt: _date(json, 'occurred_at'),
      actorId: json['actor_id'] as String?,
      metadata: metadata == null ? const {} : metadata as Map<String, Object?>,
    );
  }
}

class IssueTicketRequest {
  const IssueTicketRequest({
    required this.clientRequestId,
    required this.serviceId,
    this.appointmentId,
  });
  final String clientRequestId;
  final String serviceId;
  final String? appointmentId;

  Map<String, Object?> toJson() => {
    'client_request_id': clientRequestId,
    'service_id': serviceId,
    'appointment_id': appointmentId,
  };

  factory IssueTicketRequest.fromJson(Map<String, Object?> json) =>
      IssueTicketRequest(
        clientRequestId: _required<String>(json, 'client_request_id'),
        serviceId: _required<String>(json, 'service_id'),
        appointmentId: json['appointment_id'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is IssueTicketRequest &&
      other.clientRequestId == clientRequestId &&
      other.serviceId == serviceId &&
      other.appointmentId == appointmentId;
  @override
  int get hashCode => Object.hash(clientRequestId, serviceId, appointmentId);
}

class DayCloseReconciliation {
  const DayCloseReconciliation({
    required this.issued,
    required this.served,
    required this.waiting,
    required this.noShow,
    required this.cancelled,
  }) : expectedIssued = served + waiting + noShow + cancelled;
  final int issued;
  final int served;
  final int waiting;
  final int noShow;
  final int cancelled;
  final int expectedIssued;
  bool get isBalanced => issued == expectedIssued;

  factory DayCloseReconciliation.fromJson(Map<String, Object?> json) =>
      DayCloseReconciliation(
        issued: _required<int>(json, 'issued'),
        served: _required<int>(json, 'served'),
        waiting: _required<int>(json, 'waiting'),
        noShow: _required<int>(json, 'no_show'),
        cancelled: _required<int>(json, 'cancelled'),
      );

  Map<String, Object?> toJson() => {
    'issued': issued,
    'served': served,
    'waiting': waiting,
    'no_show': noShow,
    'cancelled': cancelled,
  };

  static DayCloseReconciliation check({
    required int issued,
    required int served,
    required int waiting,
    required int noShow,
    required int cancelled,
  }) => DayCloseReconciliation(
    issued: issued,
    served: served,
    waiting: waiting,
    noShow: noShow,
    cancelled: cancelled,
  );
}
