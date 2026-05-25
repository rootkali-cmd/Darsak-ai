import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_mobile/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsakMobileApp());
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
