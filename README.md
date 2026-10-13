# AntrianRS

Mobile Flutter client for hospital queue operations.

## Milestone 1

This milestone establishes the Android Flutter project and a read-only queue board shell. It does not connect to a backend and does not invent production queue data.

The disconnected state is explicit: the screen shows that the server is unavailable and uses placeholders instead of fake tickets.

## Business direction

The server remains source of truth for gap-free ticket numbers, idempotent issuance, priority overrides, audit events, and day-close reconciliation:

`issued = served + waiting + no_show + cancelled`

## Local verification

Run on a local PC or CI:

```sh
flutter pub get
flutter analyze
flutter test
```

Android build is intentionally not performed on the VPS. No credentials or environment values belong in this repository.

## Milestone 2

Pure Dart domain and contract boundary. No server, database, local queue numbering, or production API implementation.

Models cover queue tickets, explicit status transitions, priority override audit, append-only queue events, idempotent issue requests, typed API errors, and day-close reconciliation. Server responses are validated before entering domain models.

Backend API contract and environment configuration arrive in later milestones.
