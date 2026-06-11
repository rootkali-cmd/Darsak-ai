import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_mobile/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsakMobileApp());
    await tester.pump();
    expect(find.text('DarsakAI'), findsOneWidget);
  });
}
