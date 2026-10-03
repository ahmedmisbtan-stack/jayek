import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jayek_rider/main.dart';

void main(){
  testWidgets('rider login renders without crashing',(tester) async {
    await tester.pumpWidget(MaterialApp(home: RiderLogin(api:RiderApi(),onDone:(){})));
    await tester.pump();
    expect(find.text('جايك كابتن'),findsOneWidget);
    expect(find.text('إرسال الرمز'),findsOneWidget);
  });
}
