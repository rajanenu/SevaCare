import 'package:flutter_test/flutter_test.dart';
import 'package:sevacare_flutter/core/voice/voice_command.dart';
import 'package:sevacare_flutter/data/models/models.dart';

void main() {
  const searchRoute = '/global-search';

  VoiceAction resolve(String phrase, UserRole? role) => VoiceCommand.resolve(
        transcript: phrase,
        role: role,
        searchRoute: searchRoute,
      );

  group('patient intents', () {
    test('bare "book an appointment" opens the booking flow', () {
      final a = resolve('book an appointment', UserRole.patient);
      expect(a.route, '/patient/booking');
      expect(a.isSearch, isFalse);
    });

    test('"book with Dr Rao" searches for the doctor', () {
      final a = resolve('book appointment with Dr Rao', UserRole.patient);
      expect(a.route, searchRoute);
      expect(a.query, 'rao');
      expect(a.isSearch, isTrue);
    });

    test('prescriptions / history / appointments route correctly', () {
      expect(resolve('show my prescriptions', UserRole.patient).route,
          '/patient/prescriptions');
      expect(resolve('medical history', UserRole.patient).route,
          '/patient/medical-history');
      expect(resolve('my appointments', UserRole.patient).route,
          '/patient/appointments');
    });
  });

  group('doctor intents', () {
    test('queue and requests', () {
      expect(resolve('open my queue', UserRole.doctor).route,
          '/doctor/queue-board');
      expect(resolve('booking requests', UserRole.doctor).route,
          '/doctor/booking-requests');
    });
  });

  group('admin intents', () {
    test('reports and staff', () {
      expect(resolve('show reports', UserRole.admin).route, '/admin/reports');
      expect(resolve('my staff', UserRole.admin).route, '/admin/staff');
    });
  });

  group('common + fallback', () {
    test('notifications works for every role', () {
      expect(resolve('notifications', UserRole.patient).route, '/notifications');
      expect(resolve('notifications', UserRole.doctor).route, '/notifications');
    });

    test('explicit search strips the verb and leading article', () {
      final a = resolve('find a cardiologist', UserRole.patient);
      expect(a.route, searchRoute);
      expect(a.query, 'cardiologist');
    });

    test('unrecognised phrase falls through to a whole-phrase search', () {
      final a = resolve('paracetamol', UserRole.patient);
      expect(a.route, searchRoute);
      expect(a.query, 'paracetamol');
      expect(a.isSearch, isTrue);
    });
  });
}
