import 'package:flutter_test/flutter_test.dart';

import 'package:antrian_rs/main.dart';

void main() {
  testWidgets('shows honest disconnected queue state', (tester) async {
    await tester.pumpWidget(const AntrianRsApp());

    expect(find.text('AntrianRS'), findsOneWidget);
    expect(find.text('Server belum terhubung'), findsOneWidget);
    expect(find.text('Belum ada panggilan dari server.'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
  });
}
