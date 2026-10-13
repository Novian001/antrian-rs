import '../domain/queue_api.dart';
import '../domain/queue_domain.dart';

enum ConnectionStateKind { connected, connecting, disconnected, error }

enum CommandResultKind {
  success,
  validationError,
  unauthorized,
  forbidden,
  conflict,
  disconnected,
  timeout,
  serverError,
  invalidResponse,
}

enum UserRole { officer, triageNurse, supervisor, patient, admin }

enum CommandName {
  issueTicket,
  callTicket,
  assignPriority,
  overridePriority,
  dayClose,
  configureService,
}

Set<CommandName> visibleCommands(UserRole role) => switch (role) {
  UserRole.officer => {CommandName.issueTicket, CommandName.callTicket},
  UserRole.triageNurse => {CommandName.assignPriority},
  UserRole.supervisor => {CommandName.overridePriority, CommandName.dayClose},
  UserRole.patient => {},
  UserRole.admin => {CommandName.configureService},
};

class QueueBoardItem {
  const QueueBoardItem({
    required this.number,
    required this.service,
    required this.priority,
    required this.status,
    required this.waitLabel,
  });
  final String number;
  final String service;
  final QueuePriority priority;
  final QueueStatus status;
  final String waitLabel;

  factory QueueBoardItem.fromTicket(QueueTicket ticket) => QueueBoardItem(
    number: ticket.number,
    service: ticket.service,
    priority: ticket.priority,
    status: ticket.status,
    waitLabel: ticket.estimatedWait == null
        ? 'Estimasi belum tersedia'
        : '${ticket.estimatedWait!.inMinutes} menit',
  );
}

class CurrentTicketPresentation {
  const CurrentTicketPresentation({required this.item});
  final QueueBoardItem item;
}

class PriorityOverridePresentation {
  const PriorityOverridePresentation({required this.override});
  final PriorityOverride override;
  bool get isValid =>
      override.reason.trim().isNotEmpty && override.eventId.trim().isNotEmpty;
}

class AuditPresentation {
  const AuditPresentation({required this.event});
  final QueueEvent event;
  bool get isValid =>
      event.id.trim().isNotEmpty && event.ticketId.trim().isNotEmpty;
  String get actorLabel => event.actorId ?? 'Actor tidak tersedia';
  String get typeLabel => switch (event.type) {
    QueueEventType.noShow => 'NO-SHOW',
    QueueEventType.priorityOverride => 'PRIORITY OVERRIDE',
    QueueEventType.dayClose => 'DAY CLOSE',
    _ => event.type.name.toUpperCase(),
  };
}

class ReconciliationPresentation {
  const ReconciliationPresentation(this.value);
  final DayCloseReconciliation value;
  String get statusLabel =>
      value.isBalanced ? 'Rekonsiliasi sesuai' : 'Rekonsiliasi tidak sesuai';
}

class CommandResult<T> {
  const CommandResult(this.kind, {this.value, this.message});
  final CommandResultKind kind;
  final T? value;
  final String? message;
  bool get isSuccess => kind == CommandResultKind.success;
}

class QueueScreenState {
  const QueueScreenState({
    required this.connection,
    this.board = const [],
    this.currentTicket,
    this.audit = const [],
    this.reconciliation,
    this.errorMessage,
  });
  final ConnectionStateKind connection;
  final List<QueueBoardItem> board;
  final QueueBoardItem? currentTicket;
  final List<AuditPresentation> audit;
  final ReconciliationPresentation? reconciliation;
  final String? errorMessage;
  bool get isLoading => connection == ConnectionStateKind.connecting;
  bool get isEmpty => !isLoading && errorMessage == null && board.isEmpty;
}

class QueueController {
  QueueController(this.api, {required this.serviceId, this.onChanged});
  final QueueApi api;
  final String serviceId;
  void Function(QueueScreenState state)? onChanged;
  QueueScreenState state = const QueueScreenState(
    connection: ConnectionStateKind.disconnected,
  );

  Future<CommandResult<List<QueueBoardItem>>> refresh() async {
    state = const QueueScreenState(connection: ConnectionStateKind.connecting);
    onChanged?.call(state);
    try {
      final tickets = await api.getQueue(serviceId);
      final board = tickets
          .map(QueueBoardItem.fromTicket)
          .toList(growable: false);
      state = QueueScreenState(
        connection: ConnectionStateKind.connected,
        board: board,
      );
      onChanged?.call(state);
      return CommandResult(CommandResultKind.success, value: board);
    } on QueueApiError catch (error) {
      state = QueueScreenState(
        connection: _connectionFor(error.kind),
        errorMessage: 'Gagal memuat antrean.',
      );
      onChanged?.call(state);
      return CommandResult(_resultFor(error.kind), message: state.errorMessage);
    } on FormatException {
      state = const QueueScreenState(
        connection: ConnectionStateKind.error,
        errorMessage: 'Gagal memuat antrean.',
      );
      onChanged?.call(state);
      return const CommandResult(
        CommandResultKind.invalidResponse,
        message: 'Gagal memuat antrean.',
      );
    }
  }

  Future<CommandResult<QueueTicket>> issue(IssueTicketRequest request) async {
    try {
      final ticket = await api.issueTicket(request);
      return CommandResult(CommandResultKind.success, value: ticket);
    } on QueueApiError catch (error) {
      return CommandResult(
        _resultFor(error.kind),
        message: _safeCommandMessage(error.kind),
      );
    } on FormatException {
      return const CommandResult(
        CommandResultKind.invalidResponse,
        message: 'Respons server tidak valid.',
      );
    }
  }

  static ConnectionStateKind _connectionFor(QueueApiErrorKind kind) =>
      switch (kind) {
        QueueApiErrorKind.disconnected => ConnectionStateKind.disconnected,
        QueueApiErrorKind.timeout => ConnectionStateKind.error,
        QueueApiErrorKind.invalidResponse => ConnectionStateKind.error,
        _ => ConnectionStateKind.error,
      };

  static CommandResultKind _resultFor(QueueApiErrorKind kind) => switch (kind) {
    QueueApiErrorKind.disconnected => CommandResultKind.disconnected,
    QueueApiErrorKind.timeout => CommandResultKind.timeout,
    QueueApiErrorKind.invalidResponse => CommandResultKind.invalidResponse,
    QueueApiErrorKind.unauthorized => CommandResultKind.unauthorized,
    QueueApiErrorKind.forbidden => CommandResultKind.forbidden,
    QueueApiErrorKind.conflict => CommandResultKind.conflict,
    QueueApiErrorKind.server => CommandResultKind.serverError,
  };

  static String _safeCommandMessage(QueueApiErrorKind kind) => switch (kind) {
    QueueApiErrorKind.unauthorized => 'Sesi tidak berwenang.',
    QueueApiErrorKind.forbidden => 'Aksi tidak diizinkan untuk peran ini.',
    QueueApiErrorKind.conflict => 'Perubahan bertabrakan. Muat ulang data.',
    QueueApiErrorKind.disconnected => 'Server antrean tidak terhubung.',
    QueueApiErrorKind.timeout => 'Server terlalu lama merespons.',
    QueueApiErrorKind.invalidResponse => 'Respons server tidak valid.',
    QueueApiErrorKind.server => 'Server gagal memproses permintaan.',
  };
}
