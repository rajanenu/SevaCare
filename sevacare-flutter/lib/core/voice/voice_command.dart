import '../../data/models/models.dart';

/// The screen (and optional pre-filled search query) a spoken command resolves
/// to. [query] is only meaningful for the search route; every other route
/// ignores it.
class VoiceAction {
  /// The route to navigate to.
  final String route;

  /// A search query to pre-fill and run (search route only), or null.
  final String? query;

  /// A short human label for what we understood, shown briefly as feedback.
  final String label;

  const VoiceAction(this.route, {this.query, this.label = ''});

  bool get isSearch => query != null && query!.trim().isNotEmpty;
}

/// Turns a free-form spoken utterance into an in-app navigation, entirely on
/// the device — no network, no model call. It is deliberately forgiving: the
/// keyword tables cover the common asks per role, and *anything* it doesn't
/// recognise falls through to a search for the whole phrase, so the mic always
/// does something useful ("give the results based on that").
///
/// Pure and side-effect free so it can be unit-tested; the sheet performs the
/// actual navigation with the returned [VoiceAction].
class VoiceCommand {
  static VoiceAction resolve({
    required String transcript,
    required UserRole? role,
    required String searchRoute,
  }) {
    final raw = transcript.trim();
    final t = raw.toLowerCase();

    bool has(List<String> kws) => kws.any(t.contains);

    // ── Common to every signed-in role ──────────────────────────────────────
    if (has(['notification', 'alerts', 'सूचना', 'నోటిఫికేషన్'])) {
      return const VoiceAction('/notifications', label: 'Notifications');
    }
    if (has(['setting', 'preference', 'सेटिंग'])) {
      return const VoiceAction('/settings', label: 'Settings');
    }
    if (has(['help', 'support', 'मदद', 'సహాయం'])) {
      return const VoiceAction('/help', label: 'Help & Support');
    }

    switch (role) {
      // ── Patient ─────────────────────────────────────────────────────────
      case UserRole.patient:
        // "book" is the verb that means *make* an appointment; the bare word
        // "appointment(s)" on its own means the existing list, so it must not
        // trigger booking (or "my appointments" would open the booking flow).
        if (has(['book', 'booking', 'consult', 'बुक']) ||
            t.contains('new appointment')) {
          // "book with Dr Rao" / "book appointment for skin" → search so the
          // named doctor or specialty shows; a bare "book appointment" → the
          // booking flow itself.
          final after = _afterAny(t, ['with', 'for']);
          final q = after == null ? null : _cleanQuery(after);
          if (q != null && q.length > 1) {
            return VoiceAction(searchRoute, query: q, label: 'Searching "$q"');
          }
          return const VoiceAction('/patient/booking', label: 'Book appointment');
        }
        if (has(['my appointment', 'appointment', 'schedule', 'my visits',
            'अपॉइंटमेंट', 'అపాయింట్‌మెంట్'])) {
          return const VoiceAction('/patient/appointments', label: 'My appointments');
        }
        if (has(['prescription', 'medicine', 'medication', 'दवा'])) {
          return const VoiceAction('/patient/prescriptions', label: 'Prescriptions');
        }
        if (has(['history', 'record', 'report', 'रिपोर्ट'])) {
          return const VoiceAction('/patient/medical-history', label: 'Medical history');
        }
        if (has(['profile', 'my account'])) {
          return const VoiceAction('/patient/profile', label: 'Profile');
        }
        if (has(['home', 'dashboard'])) {
          return const VoiceAction('/patient', label: 'Home');
        }
        break;

      // ── Doctor ──────────────────────────────────────────────────────────
      case UserRole.doctor:
        if (has(['queue', 'board', 'waiting', 'my patients today'])) {
          return const VoiceAction('/doctor/queue-board', label: 'Queue board');
        }
        if (has(['consult', 'consultation', 'start consult', 'new consult'])) {
          return const VoiceAction('/doctor/consult', label: 'Consultation');
        }
        if (has(['prescription'])) {
          return const VoiceAction('/doctor/prescriptions', label: 'Prescriptions');
        }
        if (has(['request', 'booking request', 'inbox'])) {
          return const VoiceAction('/doctor/booking-requests', label: 'Booking requests');
        }
        if (has(['profile', 'my account'])) {
          return const VoiceAction('/doctor/profile', label: 'Profile');
        }
        if (has(['home', 'dashboard'])) {
          return const VoiceAction('/doctor', label: 'Home');
        }
        break;

      // ── Admin (hospital owner) ──────────────────────────────────────────
      case UserRole.admin:
        if (has(['report', 'analytics', 'insight', 'revenue', 'रिपोर्ट'])) {
          return const VoiceAction('/admin/reports', label: 'Reports');
        }
        if (has(['staff', 'team'])) {
          return const VoiceAction('/admin/staff', label: 'Staff');
        }
        if (has(['doctor'])) {
          return const VoiceAction('/admin/doctors', label: 'Doctors');
        }
        if (has(['user', 'patient'])) {
          return const VoiceAction('/admin/users', label: 'Patients');
        }
        if (has(['profile', 'my account'])) {
          return const VoiceAction('/admin/profile', label: 'Profile');
        }
        if (has(['home', 'dashboard'])) {
          return const VoiceAction('/admin', label: 'Dashboard');
        }
        break;

      // ── Staff (front desk) ──────────────────────────────────────────────
      case UserRole.staff:
        if (has(['book', 'appointment', 'register', 'new patient', 'walk in'])) {
          return const VoiceAction('/staff', label: 'Front desk');
        }
        if (has(['profile', 'my account'])) {
          return const VoiceAction('/staff/profile', label: 'Profile');
        }
        if (has(['home', 'dashboard'])) {
          return const VoiceAction('/staff', label: 'Dashboard');
        }
        break;

      case UserRole.platformAdmin:
      case null:
        break;
    }

    // ── Explicit "search / find X" phrasing ──────────────────────────────────
    if (has(['search', 'find', 'look for', 'show me', 'खोज', 'వెతుకు'])) {
      final after = _afterAny(
          t, ['search for', 'search', 'find', 'look for', 'show me', 'खोज', 'వెతుకు']);
      final q = after == null ? raw : _cleanQuery(after);
      return VoiceAction(searchRoute, query: q, label: 'Searching "$q"');
    }

    // ── Fallback: search for the whole phrase ────────────────────────────────
    return VoiceAction(searchRoute, query: raw, label: 'Searching "$raw"');
  }

  /// Returns the text after the *earliest-occurring* keyword, or null if none
  /// of the keywords appear (or nothing follows them). Earliest-occurring, not
  /// first-in-list, so "book appointment with Dr Rao" keys off "with".
  static String? _afterAny(String text, List<String> keywords) {
    var bestIndex = -1;
    var bestLen = 0;
    for (final k in keywords) {
      final i = text.indexOf(k);
      if (i >= 0 && (bestIndex < 0 || i < bestIndex)) {
        bestIndex = i;
        bestLen = k.length;
      }
    }
    if (bestIndex < 0) return null;
    final rest = text.substring(bestIndex + bestLen).trim();
    return rest.isEmpty ? null : rest;
  }

  /// Trims honorifics and articles a spoken query tends to lead with, so
  /// "dr rao" searches "rao" and "a cardiologist" searches "cardiologist".
  static String _cleanQuery(String s) {
    var q = s.trim();
    const leaders = ['doctor ', 'dr. ', 'dr ', 'the ', 'a ', 'an ', 'my '];
    var changed = true;
    while (changed) {
      changed = false;
      for (final lead in leaders) {
        if (q.startsWith(lead)) {
          q = q.substring(lead.length).trim();
          changed = true;
        }
      }
    }
    return q;
  }
}
