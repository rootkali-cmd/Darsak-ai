import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_admin/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
    expect(find.text('DarsakAI'), findsOneWidget);
  });
}
