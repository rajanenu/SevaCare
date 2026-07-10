import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sevacare_flutter/screens/admin/admin_requests_screen.dart';

/// The hospital admin's "send a message to doctors" form used to be rendered
/// inline, beneath four stacked bars of chrome. On a phone with the keyboard up
/// the Title and Message fields collapsed to a few pixels and the send button
/// slid under the footer. These tests pin the fields to a usable height in
/// exactly that situation.
void main() {
  const phone = Size(414, 760);
  const keyboardHeight = 336.0; // a typical Android IME

  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();

  Widget harness({double bottomInset = 0}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: phone,
            viewInsets: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            body: buildMessageComposerForTest(
              titleCtrl: titleCtrl,
              bodyCtrl: bodyCtrl,
            ),
          ),
        ),
      ),
    );
  }

  double heightOfFieldBelow(WidgetTester tester, String label) {
    // Each AppFormField renders its label above the TextField it owns.
    final field = find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first;
    final textField = find
        .descendant(of: field, matching: find.byType(TextField))
        .first;
    return tester.getSize(textField).height;
  }

  testWidgets('Title and Message keep a usable height with the keyboard open',
      (tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(bottomInset: keyboardHeight));
    await tester.pumpAndSettle();

    final titleHeight = heightOfFieldBelow(tester, 'Title');
    final messageHeight = heightOfFieldBelow(tester, 'Message');

    expect(titleHeight, greaterThan(40),
        reason: 'Title field collapsed to ${titleHeight}px');
    expect(messageHeight, greaterThan(80),
        reason: 'Message field collapsed to ${messageHeight}px');
  });

  testWidgets('Send button sits above the keyboard, fully on screen',
      (tester) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(bottomInset: keyboardHeight));
    await tester.pumpAndSettle();

    final send = find.text('Send to All Doctors');
    expect(send, findsOneWidget);

    final rect = tester.getRect(send);
    expect(rect.bottom, lessThanOrEqualTo(phone.height - keyboardHeight),
        reason: 'Send button is behind the keyboard (bottom=${rect.bottom})');
  });
}
