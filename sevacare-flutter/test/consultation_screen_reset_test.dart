import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sevacare_flutter/providers/app_state.dart';
import 'package:sevacare_flutter/screens/doctor/consultation_screen.dart';

void main() {
  testWidgets(
    'leaving the consult screen clears the selected patient/appointment/facet '
    'so the next visit starts blank instead of showing a stale patient',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate a doctor who previously tapped "Start Consult" on a patient.
      container.read(doctorSelectedPatientIdProvider.notifier).state = 'P-1035';
      container.read(doctorSelectedAppointmentIdProvider.notifier).state = 'APT-9999';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConsultationScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Patient: P-1035'), findsOneWidget);

      // Navigate away — unmounts ConsultationScreen and should reset state.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(doctorSelectedPatientIdProvider), isNull);
      expect(container.read(doctorSelectedAppointmentIdProvider), isNull);
      expect(container.read(doctorSelectedFacetProvider), isNull);

      // Re-entering the consult screen now shows the blank state.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConsultationScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No patient selected'), findsOneWidget);
      expect(find.text('Patient: P-1035'), findsNothing);
    },
  );
}
