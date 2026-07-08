import '../../data/models/models.dart';

/// Who a given FAQ entry is meant for. Entries tagged [FaqAudience.everyone]
/// show for all roles (intro / "who are you" style questions); role-specific
/// entries only surface for that role.
enum FaqAudience { everyone, patient, doctor, staff, admin }

/// A single predefined question the assistant can answer. [keywords] drive the
/// (offline, rule-based) matching so a user can phrase things loosely.
class FaqEntry {
  final String question;
  final String answer;
  final List<String> keywords;
  final Set<FaqAudience> audiences;

  const FaqEntry({
    required this.question,
    required this.answer,
    required this.keywords,
    required this.audiences,
  });
}

/// Maps an authenticated role (or null, pre-login) to the FAQ audience used to
/// filter the knowledge base.
FaqAudience audienceForRole(UserRole? role) => switch (role) {
      UserRole.doctor => FaqAudience.doctor,
      UserRole.staff => FaqAudience.staff,
      UserRole.admin => FaqAudience.admin,
      UserRole.patient => FaqAudience.patient,
      _ => FaqAudience.patient, // pre-login / platform-admin see patient + general
    };

/// The whole predefined knowledge base. Purely local — no network, no LLM — so
/// it works instantly, offline, on app and web, with zero cost or privacy risk.
const List<FaqEntry> kFaqEntries = [
  // ── Intro / everyone ──────────────────────────────────────────────────────
  FaqEntry(
    question: 'Who are you?',
    answer:
        "I'm the SevaCare Assistant 🤖 — a quick in-app helper. I can answer common "
        'questions about booking, queues, prescriptions and how to use SevaCare for '
        'your role. Ask me anything, or tap one of the suggestions below.',
    keywords: ['who', 'you', 'your name', 'assistant', 'bot', 'yourself'],
    audiences: {FaqAudience.everyone},
  ),
  FaqEntry(
    question: 'What is SevaCare?',
    answer:
        'SevaCare is an end-to-end healthcare platform that connects hospital admins, '
        'doctors, staff and patients in one place — appointments, live token queues, '
        'prescriptions and records, all in a single app.',
    keywords: ['what', 'sevacare', 'about', 'app', 'platform', 'do'],
    audiences: {FaqAudience.everyone},
  ),
  FaqEntry(
    question: 'How can you help me?',
    answer:
        'I can walk you through booking an appointment, understanding your token, '
        'finding prescriptions, and role-specific tasks like managing the live queue. '
        'For anything I can\'t answer, use the "Send a Message" form below to reach '
        'the support team.',
    keywords: ['help', 'how', 'support', 'assist', 'can you'],
    audiences: {FaqAudience.everyone},
  ),
  FaqEntry(
    question: 'How do I contact support?',
    answer:
        'You can reach the SevaCare team at:\n\n'
        '📧 hello@sevacareapp.com\n'
        '📞 +91 7975277345\n'
        '📍 Bangalore, India 560100\n\n'
        'You can also scroll down on the Help screen for a "Send a Message" form '
        'that reaches your hospital\'s support team directly.',
    keywords: ['contact', 'support', 'email', 'phone', 'reach', 'help desk', 'address', 'mobile', 'number', 'location'],
    audiences: {FaqAudience.everyone},
  ),
  FaqEntry(
    question: 'Is my data safe?',
    answer:
        'Yes. Your health information is stored securely and only visible to you and '
        'your care team at the hospital. We never sell your data.',
    keywords: ['data', 'safe', 'privacy', 'secure', 'security', 'private'],
    audiences: {FaqAudience.everyone},
  ),

  // ── Onboarding (hospital) ─────────────────────────────────────────────────
  FaqEntry(
    question: 'How do I onboard my hospital?',
    answer:
        'Onboarding a hospital is handled by the SevaCare team, not self-service. An '
        'authorised representative of the hospital starts it from Welcome → "Onboard '
        'Hospital", and our platform team reviews and sets up your hospital. Once it\'s '
        'live, your hospital admin can add doctors, staff and services.',
    keywords: ['onboard', 'register', 'hospital', 'sign up', 'signup', 'new hospital', 'setup', 'join'],
    audiences: {FaqAudience.everyone, FaqAudience.admin},
  ),

  // ── Patient ───────────────────────────────────────────────────────────────
  FaqEntry(
    question: 'How do I book an appointment?',
    answer:
        'Go to Home → find your hospital/doctor → pick a date and either a time slot '
        'or a token, then confirm. You\'ll receive a token number and can track your '
        'position live in the queue.',
    keywords: ['book', 'appointment', 'booking', 'schedule', 'consult', 'visit'],
    audiences: {FaqAudience.patient},
  ),
  FaqEntry(
    question: 'How do I find a doctor or hospital?',
    answer:
        'Use Search (top bar) or the hospital search on Home. You can tap "Use my '
        'location" to auto-fill your city and find nearby hospitals.',
    keywords: ['find', 'search', 'doctor', 'hospital', 'nearby', 'location', 'city'],
    audiences: {FaqAudience.patient},
  ),
  FaqEntry(
    question: 'What is a token?',
    answer:
        'A token is your place in the doctor\'s queue for a session (morning/evening). '
        'The live board shows who is "Now Serving" so you know when your turn is near.',
    keywords: ['token', 'queue', 'number', 'turn', 'position', 'waiting'],
    audiences: {FaqAudience.patient},
  ),
  FaqEntry(
    question: 'Where are my prescriptions?',
    answer:
        'Open Prescriptions from your home or bottom navigation. Every completed '
        'consultation\'s prescription is saved there and can be viewed or downloaded.',
    keywords: ['prescription', 'medicine', 'rx', 'medication', 'report', 'download'],
    audiences: {FaqAudience.patient},
  ),
  FaqEntry(
    question: 'How do I cancel or reschedule?',
    answer:
        'Open the appointment from Appointments and choose Cancel or Reschedule. '
        'Rescheduling lets you pick a new slot for the same doctor.',
    keywords: ['cancel', 'reschedule', 'change', 'move', 'appointment'],
    audiences: {FaqAudience.patient},
  ),

  // ── Doctor ────────────────────────────────────────────────────────────────
  FaqEntry(
    question: 'How do I see and manage my live queue?',
    answer:
        'Tap the "Now Serving" strip on your home to open Live Queue Control. There you '
        'can Mark Done (advances to the next token) or mark a No-show. The small TV icon '
        'opens the full-screen board for the waiting room.',
    keywords: ['queue', 'now serving', 'live', 'token', 'next', 'manage', 'control', 'board'],
    audiences: {FaqAudience.doctor},
  ),
  FaqEntry(
    question: 'How do I complete a consultation?',
    answer:
        'Open the patient from your queue, add notes/vitals and (optionally) medicines, '
        'then tap Complete. The appointment is marked completed and the queue moves on.',
    keywords: ['complete', 'consultation', 'finish', 'done', 'notes', 'vitals'],
    audiences: {FaqAudience.doctor},
  ),
  FaqEntry(
    question: 'How do I write a prescription?',
    answer:
        'Inside a consultation, use the Add Medicine section to add drugs, dosage and '
        'notes. Medicines are optional — notes/vitals alone are enough to complete.',
    keywords: ['prescription', 'prescribe', 'medicine', 'rx', 'dosage', 'write'],
    audiences: {FaqAudience.doctor},
  ),
  FaqEntry(
    question: 'How do I block slots or mark leave?',
    answer:
        'From your home use "Block slots" to make specific times unavailable, or submit '
        'a leave request for full days. Blocked/leave times stop new bookings.',
    keywords: ['block', 'slot', 'leave', 'unavailable', 'off', 'holiday'],
    audiences: {FaqAudience.doctor},
  ),

  // ── Staff ─────────────────────────────────────────────────────────────────
  FaqEntry(
    question: 'How do I use Live Queue Control?',
    answer:
        'Pick a doctor on your dashboard, then tap "Live Queue Control". You can Mark '
        'Done as each patient is seen, or No-show for anyone who didn\'t turn up — the '
        '"Now Serving" token updates for everyone instantly.',
    keywords: ['queue', 'live', 'control', 'now serving', 'no-show', 'no show', 'mark done', 'call next'],
    audiences: {FaqAudience.staff},
  ),
  FaqEntry(
    question: 'How do I book for a walk-in patient?',
    answer:
        'On the staff dashboard pick the doctor, date and session, fill the patient\'s '
        'details and confirm. A token is issued and added to the doctor\'s queue.',
    keywords: ['book', 'walk-in', 'walkin', 'patient', 'front desk', 'reception', 'appointment'],
    audiences: {FaqAudience.staff},
  ),
  FaqEntry(
    question: 'How do I check a doctor\'s availability?',
    answer:
        'Select the doctor and a date on your dashboard — the availability card shows '
        'open slots and flags if the doctor is on leave that day.',
    keywords: ['availability', 'available', 'doctor', 'leave', 'slots', 'check'],
    audiences: {FaqAudience.staff},
  ),
  FaqEntry(
    question: 'What are QR booking requests?',
    answer:
        'When patients scan the hospital QR they can request an appointment. Those show '
        'up as booking requests to confirm, which then become real appointments in the '
        'doctor\'s queue.',
    keywords: ['qr', 'request', 'scan', 'booking request', 'inbox'],
    audiences: {FaqAudience.staff, FaqAudience.doctor},
  ),

  // ── Admin ─────────────────────────────────────────────────────────────────
  FaqEntry(
    question: 'How do I add doctors, staff or admins?',
    answer:
        'This is an admin-only task. As a hospital admin, open Admin → Doctors / Staff / '
        'Admins and use "Add Doctor" (or Staff/Admin). Each new user gets a login tied '
        'to their contact mobile and signs in with an OTP. Doctors, staff and patients '
        'can\'t create these accounts themselves.',
    keywords: ['add', 'doctor', 'staff', 'admin', 'user', 'create', 'invite', 'register doctor', 'onboard doctor'],
    audiences: {FaqAudience.admin},
  ),
  FaqEntry(
    question: 'Where do I see reports and insights?',
    answer:
        'The Admin Dashboard shows live operations (queues, today\'s activity) and '
        'Reports shows performance over time — appointments, channels and collections.',
    keywords: ['report', 'insight', 'analytics', 'dashboard', 'revenue', 'performance', 'stats'],
    audiences: {FaqAudience.admin},
  ),
];
