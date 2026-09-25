import 'package:flutter_test/flutter_test.dart';
import 'package:pocketedge/main.dart';

void main() {
  testWidgets('Local Room example renders', (tester) async {
    await tester.pumpWidget(const PocketEdgeExampleApp());
    expect(find.text('PocketEdge Local Room'), findsOneWidget);
    expect(find.text('Start local host'), findsOneWidget);
  });
}
