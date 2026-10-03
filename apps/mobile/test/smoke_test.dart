import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jayek_mobile/main.dart';

void main(){
  testWidgets('customer login renders without crashing',(tester) async {
    await tester.pumpWidget(MaterialApp(home: Login(api: Api(),onDone:(){})));
    await tester.pump();
    expect(find.text('جايك'),findsOneWidget);
    expect(find.text('إرسال الرمز'),findsOneWidget);
  });
}
