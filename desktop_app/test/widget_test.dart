import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_desktop/core/local_sync/local_sync_service.dart';
import 'package:darsak_desktop/main.dart';

void main() {
  testWidgets('DarsakApp creates MaterialApp', (WidgetTester tester) async {
    final localSync = LocalSyncService();
    await tester.pumpWidget(DarsakApp(localSync: localSync));
    expect(find.byType(DarsakApp), findsOneWidget);
  });
}
