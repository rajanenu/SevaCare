import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One line of a quick template: a medicine with its default schedule.
class RxTemplateMedicine {
  final String name;
  final String strength;
  final String freq;
  final String dur;
  final String note;

  const RxTemplateMedicine({
    required this.name,
    this.strength = '',
    this.freq = '',
    this.dur = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'strength': strength,
        'freq': freq,
        'dur': dur,
        'note': note,
      };

  factory RxTemplateMedicine.fromJson(Map<String, dynamic> json) => RxTemplateMedicine(
        name: json['name'] as String? ?? '',
        strength: json['strength'] as String? ?? '',
        freq: json['freq'] as String? ?? '',
        dur: json['dur'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

/// A one-tap condition template that pre-fills medicines and clinical notes.
class RxTemplate {
  final String label;
  final IconData icon;
  final Color color;
  final String notes;
  final List<RxTemplateMedicine> medicines;

  /// Doctor-authored templates are editable and deletable; the built-in
  /// specialty sets are not.
  final bool isCustom;

  const RxTemplate({
    required this.label,
    required this.icon,
    required this.color,
    this.notes = '',
    required this.medicines,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'notes': notes,
        'medicines': medicines.map((m) => m.toJson()).toList(),
      };

  /// Custom templates round-trip through JSON, so they carry no icon/colour of
  /// their own — they all render in the "saved by you" mint styling.
  factory RxTemplate.fromJson(Map<String, dynamic> json) => RxTemplate(
        label: json['label'] as String? ?? 'Saved template',
        icon: Icons.bookmark_added_outlined,
        color: const Color(0xFF52C499),
        notes: json['notes'] as String? ?? '',
        medicines: (json['medicines'] as List? ?? const [])
            .map((e) => RxTemplateMedicine.fromJson(e as Map<String, dynamic>))
            .toList(),
        isCustom: true,
      );
}

// ── Colour palette shared by the built-in sets ────────────────────────────────

const _indigo = Color(0xFF6366F1);
const _rust = Color(0xFFDB4E2D);
const _amber = Color(0xFFF0A86B);
const _mint = Color(0xFF52C499);
const _violet = Color(0xFF7C6FE0);
const _teal = Color(0xFF2FA9A0);

/// Specialty-specific quick templates.
///
/// A cardiologist reaching for "Common Cold" every consult is friction, not a
/// shortcut. Each specialty gets the four or five presentations it actually
/// sees, and anything unrecognised falls back to [_general] — which is what a
/// general physician needs anyway.
///
/// Keys are lowercase substrings matched against the doctor's specialty string,
/// so "Skin Specialist", "Dermatology" and "Dermatologist" all resolve.
const Map<String, List<RxTemplate>> _bySpecialty = {
  'cardio': _cardiology,
  'neuro': _neurology,
  'gyn': _gynecology,
  'obstet': _gynecology,
  'derma': _dermatology,
  'skin': _dermatology,
  'dent': _dentistry,
  'pedia': _pediatrics,
  'child': _pediatrics,
  'ortho': _orthopedics,
  'ent': _ent,
  'psych': _psychiatry,
  'gastro': _gastroenterology,
  'pulmo': _pulmonology,
  'chest': _pulmonology,
  'endocrin': _endocrinology,
  'diabet': _endocrinology,
};

/// Built-in templates for [specialty], falling back to the general-medicine set.
/// Match is longest-key-first so "endocrinology" doesn't get captured by a
/// shorter key that happens to be a substring.
List<RxTemplate> builtInTemplatesFor(String? specialty) {
  final s = (specialty ?? '').toLowerCase().trim();
  if (s.isEmpty) return _general;

  final keys = _bySpecialty.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    if (s.contains(key)) return _bySpecialty[key]!;
  }
  return _general;
}

// ── Custom template storage ──────────────────────────────────────────────────

/// Doctor-authored templates, stored per doctor on the device. Deliberately
/// local: a template is a personal shortcut, not clinical data the hospital
/// needs to own, and keeping it off the server means no migration and no
/// cross-doctor leakage.
class CustomRxTemplates {
  static String _key(String doctorPublicId) => 'rx_custom_templates_$doctorPublicId';

  static Future<List<RxTemplate>> load(String doctorPublicId) async {
    if (doctorPublicId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(doctorPublicId));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => RxTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String doctorPublicId, List<RxTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(doctorPublicId),
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  /// Adds a template, replacing any existing one with the same label so a
  /// doctor refining a shortcut doesn't end up with two chips that look alike.
  static Future<List<RxTemplate>> add(String doctorPublicId, RxTemplate template) async {
    final existing = await load(doctorPublicId);
    existing.removeWhere((t) => t.label.toLowerCase() == template.label.toLowerCase());
    existing.insert(0, template);
    await _save(doctorPublicId, existing);
    return existing;
  }

  static Future<List<RxTemplate>> remove(String doctorPublicId, String label) async {
    final existing = await load(doctorPublicId);
    existing.removeWhere((t) => t.label == label);
    await _save(doctorPublicId, existing);
    return existing;
  }
}

// ── General medicine (default) ───────────────────────────────────────────────

const List<RxTemplate> _general = [
  RxTemplate(
    label: 'Common Cold',
    icon: Icons.sick_outlined,
    color: _indigo,
    notes: 'Rest, stay hydrated, avoid cold food/drinks.',
    medicines: [
      RxTemplateMedicine(name: 'Paracetamol', strength: '500mg', freq: 'TDS', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Cetirizine', strength: '10mg', freq: 'OD', dur: '5 days', note: 'At night'),
      RxTemplateMedicine(name: 'Ambroxol', strength: '30mg', freq: 'BD', dur: '5 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Hypertension',
    icon: Icons.favorite_border,
    color: _rust,
    notes: 'Low-salt diet. Monitor BP daily. Follow up in 2 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Amlodipine', strength: '5mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Telmisartan', strength: '40mg', freq: 'OD', dur: '30 days', note: 'Morning'),
    ],
  ),
  RxTemplate(
    label: 'Diabetes F/U',
    icon: Icons.water_drop_outlined,
    color: _amber,
    notes: 'Check HbA1c in 3 months. Low-sugar diet. Walk 30 min daily.',
    medicines: [
      RxTemplateMedicine(name: 'Metformin', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Glimepiride', strength: '1mg', freq: 'OD', dur: '30 days', note: 'Before breakfast'),
    ],
  ),
  RxTemplate(
    label: 'Gastritis',
    icon: Icons.medication_outlined,
    color: _mint,
    notes: 'Avoid spicy food, alcohol, NSAIDs. Eat small frequent meals.',
    medicines: [
      RxTemplateMedicine(name: 'Pantoprazole', strength: '40mg', freq: 'OD', dur: '14 days', note: '30 min before food'),
      RxTemplateMedicine(name: 'Domperidone', strength: '10mg', freq: 'TDS', dur: '7 days', note: 'Before meals'),
      RxTemplateMedicine(name: 'Sucralfate', strength: '1g', freq: 'TDS', dur: '7 days', note: 'After meals'),
    ],
  ),
  RxTemplate(
    label: 'Viral Fever',
    icon: Icons.thermostat_outlined,
    color: _violet,
    notes: 'Plenty of fluids. Return if fever persists beyond 3 days.',
    medicines: [
      RxTemplateMedicine(name: 'Paracetamol', strength: '650mg', freq: 'SOS', dur: '3 days', note: 'If temp > 100°F'),
      RxTemplateMedicine(name: 'ORS', strength: '1 sachet', freq: 'TDS', dur: '3 days', note: 'In 1L water'),
      RxTemplateMedicine(name: 'Multivitamin', strength: '1 tab', freq: 'OD', dur: '10 days', note: 'After breakfast'),
    ],
  ),
];

// ── Cardiology ───────────────────────────────────────────────────────────────

const List<RxTemplate> _cardiology = [
  RxTemplate(
    label: 'Hypertension',
    icon: Icons.favorite_border,
    color: _rust,
    notes: 'Low-salt diet (<5g/day). Home BP log twice daily. Review in 2 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Telmisartan', strength: '40mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Amlodipine', strength: '5mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Hydrochlorothiazide', strength: '12.5mg', freq: 'OD', dur: '30 days', note: 'Morning'),
    ],
  ),
  RxTemplate(
    label: 'Post-MI / CAD',
    icon: Icons.monitor_heart_outlined,
    color: _indigo,
    notes: 'Dual antiplatelet for 12 months. No NSAIDs. Cardiac rehab advised.',
    medicines: [
      RxTemplateMedicine(name: 'Aspirin', strength: '75mg', freq: 'OD', dur: '30 days', note: 'After lunch'),
      RxTemplateMedicine(name: 'Clopidogrel', strength: '75mg', freq: 'OD', dur: '30 days', note: 'After lunch'),
      RxTemplateMedicine(name: 'Atorvastatin', strength: '40mg', freq: 'OD', dur: '30 days', note: 'At night'),
      RxTemplateMedicine(name: 'Metoprolol', strength: '25mg', freq: 'BD', dur: '30 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Heart Failure',
    icon: Icons.favorite,
    color: _violet,
    notes: 'Daily weight log. Fluid restriction 1.5L/day. Report weight gain >2kg in 3 days.',
    medicines: [
      RxTemplateMedicine(name: 'Furosemide', strength: '40mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Ramipril', strength: '2.5mg', freq: 'OD', dur: '30 days', note: 'At night'),
      RxTemplateMedicine(name: 'Spironolactone', strength: '25mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Carvedilol', strength: '3.125mg', freq: 'BD', dur: '30 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Dyslipidemia',
    icon: Icons.show_chart,
    color: _amber,
    notes: 'Repeat lipid profile in 8 weeks. Reduce saturated fat. 30 min brisk walk daily.',
    medicines: [
      RxTemplateMedicine(name: 'Rosuvastatin', strength: '10mg', freq: 'OD', dur: '30 days', note: 'At night'),
      RxTemplateMedicine(name: 'Fenofibrate', strength: '145mg', freq: 'OD', dur: '30 days', note: 'After dinner'),
    ],
  ),
  RxTemplate(
    label: 'Atrial Fibrillation',
    icon: Icons.timeline,
    color: _teal,
    notes: 'Anticoagulation — watch for bleeding. Check INR/renal function as advised.',
    medicines: [
      RxTemplateMedicine(name: 'Apixaban', strength: '5mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Metoprolol', strength: '25mg', freq: 'BD', dur: '30 days', note: 'After food'),
    ],
  ),
];

// ── Neurology ────────────────────────────────────────────────────────────────

const List<RxTemplate> _neurology = [
  RxTemplate(
    label: 'Migraine',
    icon: Icons.psychology_outlined,
    color: _violet,
    notes: 'Identify and avoid triggers. Rest in a dark, quiet room during an attack.',
    medicines: [
      RxTemplateMedicine(name: 'Sumatriptan', strength: '50mg', freq: 'SOS', dur: 'As needed', note: 'At onset'),
      RxTemplateMedicine(name: 'Naproxen', strength: '500mg', freq: 'BD', dur: '3 days', note: 'With food'),
      RxTemplateMedicine(name: 'Propranolol', strength: '20mg', freq: 'BD', dur: '30 days', note: 'Prevention'),
    ],
  ),
  RxTemplate(
    label: 'Epilepsy',
    icon: Icons.bolt_outlined,
    color: _indigo,
    notes: 'Never stop abruptly. No driving or swimming alone until seizure-free 6 months.',
    medicines: [
      RxTemplateMedicine(name: 'Levetiracetam', strength: '500mg', freq: 'BD', dur: '30 days', note: 'Fixed timings'),
      RxTemplateMedicine(name: 'Folic Acid', strength: '5mg', freq: 'OD', dur: '30 days', note: 'Morning'),
    ],
  ),
  RxTemplate(
    label: 'Neuropathic Pain',
    icon: Icons.electric_bolt_outlined,
    color: _amber,
    notes: 'Drowsiness expected in the first week. Titrate slowly.',
    medicines: [
      RxTemplateMedicine(name: 'Pregabalin', strength: '75mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Amitriptyline', strength: '10mg', freq: 'OD', dur: '30 days', note: 'At bedtime'),
      RxTemplateMedicine(name: 'Vitamin B12', strength: '1500mcg', freq: 'OD', dur: '30 days', note: 'After breakfast'),
    ],
  ),
  RxTemplate(
    label: 'Vertigo',
    icon: Icons.threesixty,
    color: _teal,
    notes: 'Avoid sudden head movement. Epley manoeuvre demonstrated.',
    medicines: [
      RxTemplateMedicine(name: 'Betahistine', strength: '16mg', freq: 'TDS', dur: '14 days', note: 'After food'),
      RxTemplateMedicine(name: 'Cinnarizine', strength: '25mg', freq: 'BD', dur: '7 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Post-Stroke',
    icon: Icons.accessibility_new,
    color: _rust,
    notes: 'Physiotherapy daily. BP and sugar control critical. Review in 4 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Aspirin', strength: '75mg', freq: 'OD', dur: '30 days', note: 'After lunch'),
      RxTemplateMedicine(name: 'Atorvastatin', strength: '40mg', freq: 'OD', dur: '30 days', note: 'At night'),
      RxTemplateMedicine(name: 'Clopidogrel', strength: '75mg', freq: 'OD', dur: '30 days', note: 'After lunch'),
    ],
  ),
];

// ── Gynecology & Obstetrics ──────────────────────────────────────────────────

const List<RxTemplate> _gynecology = [
  RxTemplate(
    label: 'Antenatal Care',
    icon: Icons.pregnant_woman_outlined,
    color: _violet,
    notes: 'Iron after 12 weeks. Regular scans. Report bleeding or reduced fetal movement.',
    medicines: [
      RxTemplateMedicine(name: 'Folic Acid', strength: '5mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Ferrous Sulphate', strength: '100mg', freq: 'OD', dur: '30 days', note: 'After lunch'),
      RxTemplateMedicine(name: 'Calcium Carbonate', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After meals'),
    ],
  ),
  RxTemplate(
    label: 'PCOS',
    icon: Icons.spa_outlined,
    color: _mint,
    notes: 'Weight reduction 5-10%. Low glycaemic diet. Review cycles in 3 months.',
    medicines: [
      RxTemplateMedicine(name: 'Metformin', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Myo-Inositol', strength: '2g', freq: 'BD', dur: '30 days', note: 'Before meals'),
      RxTemplateMedicine(name: 'Vitamin D3', strength: '60000 IU', freq: 'Weekly', dur: '8 weeks', note: 'After breakfast'),
    ],
  ),
  RxTemplate(
    label: 'Anemia',
    icon: Icons.bloodtype_outlined,
    color: _rust,
    notes: 'Take iron with citrus, not with tea or milk. Repeat Hb in 4 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Ferrous Sulphate', strength: '200mg', freq: 'BD', dur: '30 days', note: 'Empty stomach'),
      RxTemplateMedicine(name: 'Vitamin C', strength: '500mg', freq: 'OD', dur: '30 days', note: 'With iron'),
      RxTemplateMedicine(name: 'Folic Acid', strength: '5mg', freq: 'OD', dur: '30 days', note: 'Morning'),
    ],
  ),
  RxTemplate(
    label: 'UTI',
    icon: Icons.water_drop_outlined,
    color: _indigo,
    notes: 'Drink 3L water daily. Complete the full antibiotic course.',
    medicines: [
      RxTemplateMedicine(name: 'Nitrofurantoin', strength: '100mg', freq: 'BD', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Potassium Citrate', strength: '10ml', freq: 'TDS', dur: '5 days', note: 'In water'),
    ],
  ),
  RxTemplate(
    label: 'Dysmenorrhea',
    icon: Icons.healing_outlined,
    color: _amber,
    notes: 'Start at first sign of pain. Warm compress helps. Rule out endometriosis if severe.',
    medicines: [
      RxTemplateMedicine(name: 'Mefenamic Acid', strength: '500mg', freq: 'TDS', dur: '3 days', note: 'After food'),
      RxTemplateMedicine(name: 'Drotaverine', strength: '80mg', freq: 'BD', dur: '3 days', note: 'SOS for cramps'),
    ],
  ),
];

// ── Dermatology / Skin ───────────────────────────────────────────────────────

const List<RxTemplate> _dermatology = [
  RxTemplate(
    label: 'Fungal Infection',
    icon: Icons.grain,
    color: _amber,
    notes: 'Keep the area dry. Wash and sun-dry clothing. Treat all family members if spreading.',
    medicines: [
      RxTemplateMedicine(name: 'Itraconazole', strength: '100mg', freq: 'BD', dur: '21 days', note: 'After food'),
      RxTemplateMedicine(name: 'Ketoconazole Cream', strength: '2%', freq: 'BD', dur: '21 days', note: 'Apply thinly'),
      RxTemplateMedicine(name: 'Levocetrizine', strength: '5mg', freq: 'OD', dur: '10 days', note: 'At night'),
    ],
  ),
  RxTemplate(
    label: 'Acne Vulgaris',
    icon: Icons.face_retouching_natural,
    color: _violet,
    notes: 'No scrubbing or picking. Non-comedogenic sunscreen daily. Review in 6 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Adapalene Gel', strength: '0.1%', freq: 'OD', dur: '30 days', note: 'At night'),
      RxTemplateMedicine(name: 'Clindamycin Gel', strength: '1%', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Doxycycline', strength: '100mg', freq: 'OD', dur: '14 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Eczema',
    icon: Icons.spa_outlined,
    color: _mint,
    notes: 'Lukewarm showers, fragrance-free moisturiser twice daily. Avoid known allergens.',
    medicines: [
      RxTemplateMedicine(name: 'Hydrocortisone Cream', strength: '1%', freq: 'BD', dur: '7 days', note: 'Thin layer'),
      RxTemplateMedicine(name: 'Cetirizine', strength: '10mg', freq: 'OD', dur: '10 days', note: 'At night'),
    ],
  ),
  RxTemplate(
    label: 'Urticaria',
    icon: Icons.blur_on,
    color: _rust,
    notes: 'Identify and avoid trigger. Seek emergency care if lips or throat swell.',
    medicines: [
      RxTemplateMedicine(name: 'Fexofenadine', strength: '180mg', freq: 'OD', dur: '14 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Montelukast', strength: '10mg', freq: 'OD', dur: '14 days', note: 'At night'),
    ],
  ),
  RxTemplate(
    label: 'Scabies',
    icon: Icons.pest_control_outlined,
    color: _indigo,
    notes: 'Apply neck-down overnight, wash off after 8-12h. Treat all household contacts on the same day.',
    medicines: [
      RxTemplateMedicine(name: 'Permethrin Cream', strength: '5%', freq: 'Once', dur: 'Repeat in 7 days', note: 'Overnight'),
      RxTemplateMedicine(name: 'Ivermectin', strength: '12mg', freq: 'Once', dur: 'Repeat in 7 days', note: 'Empty stomach'),
      RxTemplateMedicine(name: 'Levocetrizine', strength: '5mg', freq: 'OD', dur: '10 days', note: 'At night'),
    ],
  ),
];

// ── Dentistry ────────────────────────────────────────────────────────────────

const List<RxTemplate> _dentistry = [
  RxTemplate(
    label: 'Dental Abscess',
    icon: Icons.emergency_outlined,
    color: _rust,
    notes: 'Warm saline rinses 4x daily. Root canal or extraction after infection settles.',
    medicines: [
      RxTemplateMedicine(name: 'Amoxicillin-Clavulanate', strength: '625mg', freq: 'TDS', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Metronidazole', strength: '400mg', freq: 'TDS', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Ibuprofen', strength: '400mg', freq: 'TDS', dur: '3 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Post-Extraction',
    icon: Icons.healing_outlined,
    color: _indigo,
    notes: 'No spitting, rinsing or straws for 24h. Cold compress today, soft diet 3 days.',
    medicines: [
      RxTemplateMedicine(name: 'Amoxicillin', strength: '500mg', freq: 'TDS', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Paracetamol', strength: '650mg', freq: 'TDS', dur: '3 days', note: 'After food'),
      RxTemplateMedicine(name: 'Chlorhexidine Mouthwash', strength: '0.2%', freq: 'BD', dur: '7 days', note: 'From day 2'),
    ],
  ),
  RxTemplate(
    label: 'Gingivitis',
    icon: Icons.cleaning_services_outlined,
    color: _mint,
    notes: 'Scaling done. Soft brush twice daily, floss nightly. Recall in 6 months.',
    medicines: [
      RxTemplateMedicine(name: 'Chlorhexidine Mouthwash', strength: '0.2%', freq: 'BD', dur: '14 days', note: 'After brushing'),
      RxTemplateMedicine(name: 'Vitamin C', strength: '500mg', freq: 'OD', dur: '14 days', note: 'After breakfast'),
    ],
  ),
  RxTemplate(
    label: 'Sensitivity',
    icon: Icons.ac_unit_outlined,
    color: _teal,
    notes: 'Avoid very hot/cold foods and acidic drinks. Do not brush immediately after citrus.',
    medicines: [
      RxTemplateMedicine(name: 'Potassium Nitrate Toothpaste', strength: '5%', freq: 'BD', dur: '30 days', note: 'Massage on gums'),
      RxTemplateMedicine(name: 'Fluoride Gel', strength: '1.1%', freq: 'OD', dur: '30 days', note: 'At night'),
    ],
  ),
];

// ── Pediatrics ───────────────────────────────────────────────────────────────

const List<RxTemplate> _pediatrics = [
  RxTemplate(
    label: 'Fever (Child)',
    icon: Icons.thermostat_outlined,
    color: _rust,
    notes: 'Doses are weight-based — confirm before issuing. Tepid sponging. Return if fever >3 days.',
    medicines: [
      RxTemplateMedicine(name: 'Paracetamol Syrup', strength: '15mg/kg', freq: 'QID', dur: '3 days', note: 'SOS if temp > 100°F'),
      RxTemplateMedicine(name: 'ORS', strength: '1 sachet', freq: 'SOS', dur: '3 days', note: 'In 1L water'),
    ],
  ),
  RxTemplate(
    label: 'Acute Diarrhoea',
    icon: Icons.water_drop_outlined,
    color: _teal,
    notes: 'Continue feeding. Watch for sunken eyes, no urine 6h, lethargy — return immediately.',
    medicines: [
      RxTemplateMedicine(name: 'ORS', strength: '1 sachet', freq: 'After each stool', dur: '5 days', note: 'In 1L water'),
      RxTemplateMedicine(name: 'Zinc', strength: '20mg', freq: 'OD', dur: '14 days', note: 'After food'),
      RxTemplateMedicine(name: 'Racecadotril', strength: '1.5mg/kg', freq: 'TDS', dur: '3 days', note: 'Before feeds'),
    ],
  ),
  RxTemplate(
    label: 'URI / Cold',
    icon: Icons.sick_outlined,
    color: _indigo,
    notes: 'Saline nasal drops before feeds. No cough syrup under 2 years.',
    medicines: [
      RxTemplateMedicine(name: 'Paracetamol Syrup', strength: '15mg/kg', freq: 'QID', dur: '3 days', note: 'SOS for fever'),
      RxTemplateMedicine(name: 'Saline Nasal Drops', strength: '0.65%', freq: 'QID', dur: '5 days', note: '2 drops each nostril'),
    ],
  ),
  RxTemplate(
    label: 'Wheeze / Asthma',
    icon: Icons.air,
    color: _violet,
    notes: 'Spacer technique demonstrated to parent. Avoid smoke and dust. Review in 1 week.',
    medicines: [
      RxTemplateMedicine(name: 'Salbutamol Inhaler', strength: '100mcg', freq: 'SOS', dur: '30 days', note: '2 puffs via spacer'),
      RxTemplateMedicine(name: 'Budesonide Inhaler', strength: '100mcg', freq: 'BD', dur: '30 days', note: 'Rinse mouth after'),
      RxTemplateMedicine(name: 'Montelukast', strength: '4mg', freq: 'OD', dur: '30 days', note: 'At bedtime'),
    ],
  ),
  RxTemplate(
    label: 'Deworming + Nutrition',
    icon: Icons.child_care_outlined,
    color: _mint,
    notes: 'Repeat deworming every 6 months. Growth chart plotted and discussed.',
    medicines: [
      RxTemplateMedicine(name: 'Albendazole', strength: '400mg', freq: 'Once', dur: 'Single dose', note: 'Chew at night'),
      RxTemplateMedicine(name: 'Multivitamin Syrup', strength: '5ml', freq: 'OD', dur: '30 days', note: 'After breakfast'),
      RxTemplateMedicine(name: 'Iron Syrup', strength: '3mg/kg', freq: 'OD', dur: '30 days', note: 'After food'),
    ],
  ),
];

// ── Orthopedics ──────────────────────────────────────────────────────────────

const List<RxTemplate> _orthopedics = [
  RxTemplate(
    label: 'Osteoarthritis',
    icon: Icons.accessibility_new,
    color: _amber,
    notes: 'Quadriceps strengthening daily. Weight reduction. Avoid squatting and stairs.',
    medicines: [
      RxTemplateMedicine(name: 'Etoricoxib', strength: '60mg', freq: 'OD', dur: '10 days', note: 'After food'),
      RxTemplateMedicine(name: 'Glucosamine', strength: '750mg', freq: 'BD', dur: '30 days', note: 'After meals'),
      RxTemplateMedicine(name: 'Calcium Carbonate', strength: '500mg', freq: 'OD', dur: '30 days', note: 'After dinner'),
    ],
  ),
  RxTemplate(
    label: 'Low Back Pain',
    icon: Icons.airline_seat_flat_angled,
    color: _indigo,
    notes: 'Firm mattress. No forward bending or heavy lifting. Core exercises from day 5.',
    medicines: [
      RxTemplateMedicine(name: 'Diclofenac', strength: '50mg', freq: 'BD', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Tizanidine', strength: '2mg', freq: 'BD', dur: '5 days', note: 'May cause drowsiness'),
      RxTemplateMedicine(name: 'Diclofenac Gel', strength: '1%', freq: 'TDS', dur: '7 days', note: 'Local application'),
    ],
  ),
  RxTemplate(
    label: 'Post-Fracture',
    icon: Icons.healing_outlined,
    color: _teal,
    notes: 'Cast care explained. Elevate limb. Return immediately for numbness or blue fingers.',
    medicines: [
      RxTemplateMedicine(name: 'Paracetamol', strength: '650mg', freq: 'TDS', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Calcium Carbonate', strength: '500mg', freq: 'BD', dur: '45 days', note: 'After meals'),
      RxTemplateMedicine(name: 'Vitamin D3', strength: '60000 IU', freq: 'Weekly', dur: '8 weeks', note: 'After breakfast'),
    ],
  ),
  RxTemplate(
    label: 'Gout',
    icon: Icons.local_fire_department_outlined,
    color: _rust,
    notes: 'Avoid red meat, seafood, alcohol. 3L water daily. Do not start urate-lowering during an attack.',
    medicines: [
      RxTemplateMedicine(name: 'Colchicine', strength: '0.5mg', freq: 'BD', dur: '5 days', note: 'Stop if diarrhoea'),
      RxTemplateMedicine(name: 'Naproxen', strength: '500mg', freq: 'BD', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Febuxostat', strength: '40mg', freq: 'OD', dur: '30 days', note: 'Start after attack settles'),
    ],
  ),
  RxTemplate(
    label: 'Osteoporosis',
    icon: Icons.grid_on,
    color: _violet,
    notes: 'Take on an empty stomach with a full glass of water; stay upright 30 min. DEXA in 1 year.',
    medicines: [
      RxTemplateMedicine(name: 'Alendronate', strength: '70mg', freq: 'Weekly', dur: '12 weeks', note: 'Empty stomach'),
      RxTemplateMedicine(name: 'Calcium Carbonate', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After meals'),
      RxTemplateMedicine(name: 'Vitamin D3', strength: '60000 IU', freq: 'Weekly', dur: '8 weeks', note: 'After breakfast'),
    ],
  ),
];

// ── ENT ──────────────────────────────────────────────────────────────────────

const List<RxTemplate> _ent = [
  RxTemplate(
    label: 'Acute Pharyngitis',
    icon: Icons.record_voice_over_outlined,
    color: _indigo,
    notes: 'Warm saline gargles 4x daily. Voice rest. Complete the antibiotic course.',
    medicines: [
      RxTemplateMedicine(name: 'Amoxicillin', strength: '500mg', freq: 'TDS', dur: '5 days', note: 'After food'),
      RxTemplateMedicine(name: 'Paracetamol', strength: '650mg', freq: 'TDS', dur: '3 days', note: 'After food'),
      RxTemplateMedicine(name: 'Chlorhexidine Gargle', strength: '0.2%', freq: 'QID', dur: '5 days', note: 'Do not swallow'),
    ],
  ),
  RxTemplate(
    label: 'Allergic Rhinitis',
    icon: Icons.air,
    color: _mint,
    notes: 'Dust-mite precautions. Steam inhalation twice daily. Nasal spray technique demonstrated.',
    medicines: [
      RxTemplateMedicine(name: 'Fexofenadine', strength: '120mg', freq: 'OD', dur: '14 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Fluticasone Nasal Spray', strength: '50mcg', freq: 'BD', dur: '30 days', note: '2 sprays each nostril'),
      RxTemplateMedicine(name: 'Montelukast', strength: '10mg', freq: 'OD', dur: '30 days', note: 'At night'),
    ],
  ),
  RxTemplate(
    label: 'Otitis Media',
    icon: Icons.hearing_outlined,
    color: _rust,
    notes: 'Keep the ear dry — no swimming or oil instillation. Review in 1 week.',
    medicines: [
      RxTemplateMedicine(name: 'Amoxicillin-Clavulanate', strength: '625mg', freq: 'BD', dur: '7 days', note: 'After food'),
      RxTemplateMedicine(name: 'Ibuprofen', strength: '400mg', freq: 'TDS', dur: '3 days', note: 'After food'),
      RxTemplateMedicine(name: 'Xylometazoline Nasal Drops', strength: '0.1%', freq: 'TDS', dur: '5 days', note: 'Max 5 days'),
    ],
  ),
  RxTemplate(
    label: 'Sinusitis',
    icon: Icons.face_outlined,
    color: _violet,
    notes: 'Steam inhalation 3x daily. Sleep with head elevated. CT only if not improving in 10 days.',
    medicines: [
      RxTemplateMedicine(name: 'Amoxicillin-Clavulanate', strength: '625mg', freq: 'BD', dur: '10 days', note: 'After food'),
      RxTemplateMedicine(name: 'Fluticasone Nasal Spray', strength: '50mcg', freq: 'BD', dur: '14 days', note: '2 sprays each nostril'),
      RxTemplateMedicine(name: 'Levocetrizine', strength: '5mg', freq: 'OD', dur: '10 days', note: 'At night'),
    ],
  ),
];

// ── Psychiatry ───────────────────────────────────────────────────────────────

const List<RxTemplate> _psychiatry = [
  RxTemplate(
    label: 'Depression',
    icon: Icons.sentiment_dissatisfied_outlined,
    color: _indigo,
    notes: 'Effect builds over 2-4 weeks. Do not stop abruptly. Review in 2 weeks; screen for suicidality.',
    medicines: [
      RxTemplateMedicine(name: 'Escitalopram', strength: '10mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Clonazepam', strength: '0.25mg', freq: 'OD', dur: '7 days', note: 'At bedtime, short term'),
    ],
  ),
  RxTemplate(
    label: 'Anxiety Disorder',
    icon: Icons.self_improvement_outlined,
    color: _mint,
    notes: 'Breathing exercises and CBT referral. Limit caffeine. Benzodiazepine is short-term only.',
    medicines: [
      RxTemplateMedicine(name: 'Sertraline', strength: '50mg', freq: 'OD', dur: '30 days', note: 'After breakfast'),
      RxTemplateMedicine(name: 'Propranolol', strength: '20mg', freq: 'SOS', dur: '14 days', note: 'For palpitations'),
    ],
  ),
  RxTemplate(
    label: 'Insomnia',
    icon: Icons.bedtime_outlined,
    color: _violet,
    notes: 'Sleep hygiene first: fixed wake time, no screens 1h before bed, no daytime naps.',
    medicines: [
      RxTemplateMedicine(name: 'Melatonin', strength: '3mg', freq: 'OD', dur: '14 days', note: '1h before bed'),
      RxTemplateMedicine(name: 'Zolpidem', strength: '5mg', freq: 'SOS', dur: '7 days', note: 'Short term only'),
    ],
  ),
  RxTemplate(
    label: 'Bipolar Maintenance',
    icon: Icons.balance_outlined,
    color: _amber,
    notes: 'Monitor lithium level, TSH and renal function. Maintain steady salt and fluid intake.',
    medicines: [
      RxTemplateMedicine(name: 'Lithium Carbonate', strength: '300mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Olanzapine', strength: '5mg', freq: 'OD', dur: '30 days', note: 'At bedtime'),
    ],
  ),
];

// ── Gastroenterology ─────────────────────────────────────────────────────────

const List<RxTemplate> _gastroenterology = [
  RxTemplate(
    label: 'GERD',
    icon: Icons.local_fire_department_outlined,
    color: _rust,
    notes: 'No food 3h before bed. Elevate head end. Avoid citrus, coffee, spicy food, smoking.',
    medicines: [
      RxTemplateMedicine(name: 'Pantoprazole', strength: '40mg', freq: 'OD', dur: '30 days', note: '30 min before breakfast'),
      RxTemplateMedicine(name: 'Domperidone', strength: '10mg', freq: 'TDS', dur: '14 days', note: 'Before meals'),
      RxTemplateMedicine(name: 'Gelusil', strength: '10ml', freq: 'SOS', dur: '14 days', note: 'For breakthrough burn'),
    ],
  ),
  RxTemplate(
    label: 'IBS',
    icon: Icons.grain,
    color: _mint,
    notes: 'Low-FODMAP trial for 4 weeks. Regular meals, stress management. Symptom diary.',
    medicines: [
      RxTemplateMedicine(name: 'Mebeverine', strength: '135mg', freq: 'TDS', dur: '30 days', note: '20 min before meals'),
      RxTemplateMedicine(name: 'Ispaghula Husk', strength: '5g', freq: 'OD', dur: '30 days', note: 'At night with water'),
      RxTemplateMedicine(name: 'Probiotic', strength: '1 capsule', freq: 'OD', dur: '30 days', note: 'After breakfast'),
    ],
  ),
  RxTemplate(
    label: 'Acute Gastritis',
    icon: Icons.medication_outlined,
    color: _indigo,
    notes: 'Stop NSAIDs and alcohol. Small frequent bland meals for 1 week.',
    medicines: [
      RxTemplateMedicine(name: 'Pantoprazole', strength: '40mg', freq: 'OD', dur: '14 days', note: '30 min before food'),
      RxTemplateMedicine(name: 'Sucralfate', strength: '1g', freq: 'TDS', dur: '7 days', note: 'After meals'),
      RxTemplateMedicine(name: 'Ondansetron', strength: '4mg', freq: 'SOS', dur: '3 days', note: 'For vomiting'),
    ],
  ),
  RxTemplate(
    label: 'Constipation',
    icon: Icons.timelapse_outlined,
    color: _amber,
    notes: 'High-fibre diet, 3L water, 30 min walk daily. Do not suppress the urge.',
    medicines: [
      RxTemplateMedicine(name: 'Lactulose', strength: '15ml', freq: 'OD', dur: '14 days', note: 'At bedtime'),
      RxTemplateMedicine(name: 'Ispaghula Husk', strength: '5g', freq: 'OD', dur: '30 days', note: 'At night with water'),
      RxTemplateMedicine(name: 'Bisacodyl', strength: '5mg', freq: 'SOS', dur: '7 days', note: 'If no stool 3 days'),
    ],
  ),
];

// ── Pulmonology ──────────────────────────────────────────────────────────────

const List<RxTemplate> _pulmonology = [
  RxTemplate(
    label: 'Bronchial Asthma',
    icon: Icons.air,
    color: _violet,
    notes: 'Inhaler technique demonstrated. Rinse mouth after steroid inhaler. Peak-flow diary.',
    medicines: [
      RxTemplateMedicine(name: 'Budesonide Inhaler', strength: '200mcg', freq: 'BD', dur: '30 days', note: 'Rinse mouth after'),
      RxTemplateMedicine(name: 'Salbutamol Inhaler', strength: '100mcg', freq: 'SOS', dur: '30 days', note: '2 puffs when breathless'),
      RxTemplateMedicine(name: 'Montelukast', strength: '10mg', freq: 'OD', dur: '30 days', note: 'At bedtime'),
    ],
  ),
  RxTemplate(
    label: 'COPD',
    icon: Icons.smoke_free_outlined,
    color: _teal,
    notes: 'Smoking cessation is the single most effective step. Flu and pneumococcal vaccination advised.',
    medicines: [
      RxTemplateMedicine(name: 'Tiotropium Inhaler', strength: '18mcg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Formoterol-Budesonide', strength: '6/200mcg', freq: 'BD', dur: '30 days', note: 'Rinse mouth after'),
      RxTemplateMedicine(name: 'Acebrophylline', strength: '100mg', freq: 'BD', dur: '14 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'LRTI / Pneumonia',
    icon: Icons.masks_outlined,
    color: _rust,
    notes: 'Chest X-ray done. Return for breathlessness or persistent fever. Steam inhalation.',
    medicines: [
      RxTemplateMedicine(name: 'Amoxicillin-Clavulanate', strength: '625mg', freq: 'TDS', dur: '7 days', note: 'After food'),
      RxTemplateMedicine(name: 'Azithromycin', strength: '500mg', freq: 'OD', dur: '5 days', note: 'Empty stomach'),
      RxTemplateMedicine(name: 'Ambroxol', strength: '30mg', freq: 'TDS', dur: '7 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Chronic Cough',
    icon: Icons.sick_outlined,
    color: _indigo,
    notes: 'Rule out GERD, asthma and post-nasal drip. Stop ACE inhibitor if on one.',
    medicines: [
      RxTemplateMedicine(name: 'Levocetrizine + Montelukast', strength: '5/10mg', freq: 'OD', dur: '14 days', note: 'At night'),
      RxTemplateMedicine(name: 'Dextromethorphan', strength: '10ml', freq: 'TDS', dur: '7 days', note: 'For dry cough'),
      RxTemplateMedicine(name: 'Pantoprazole', strength: '40mg', freq: 'OD', dur: '14 days', note: 'Before breakfast'),
    ],
  ),
];

// ── Endocrinology / Diabetology ──────────────────────────────────────────────

const List<RxTemplate> _endocrinology = [
  RxTemplate(
    label: 'Type 2 Diabetes',
    icon: Icons.water_drop_outlined,
    color: _amber,
    notes: 'HbA1c in 3 months. Low-glycaemic diet, 30 min brisk walk daily. Annual eye and foot check.',
    medicines: [
      RxTemplateMedicine(name: 'Metformin', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Sitagliptin', strength: '100mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      RxTemplateMedicine(name: 'Atorvastatin', strength: '10mg', freq: 'OD', dur: '30 days', note: 'At night'),
    ],
  ),
  RxTemplate(
    label: 'Hypothyroidism',
    icon: Icons.spa_outlined,
    color: _teal,
    notes: 'Empty stomach, 45 min before breakfast, no calcium or iron within 4h. TSH in 6 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Levothyroxine', strength: '50mcg', freq: 'OD', dur: '42 days', note: 'Empty stomach'),
    ],
  ),
  RxTemplate(
    label: 'Insulin Start',
    icon: Icons.vaccines_outlined,
    color: _rust,
    notes: 'Injection technique and site rotation taught. Hypoglycaemia symptoms explained. SMBG log.',
    medicines: [
      RxTemplateMedicine(name: 'Insulin Glargine', strength: '10 units', freq: 'OD', dur: '30 days', note: 'At bedtime, titrate'),
      RxTemplateMedicine(name: 'Metformin', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After food'),
    ],
  ),
  RxTemplate(
    label: 'Vitamin D Deficiency',
    icon: Icons.wb_sunny_outlined,
    color: _mint,
    notes: '20 min sun exposure daily. Recheck 25-OH vitamin D after 8 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Vitamin D3', strength: '60000 IU', freq: 'Weekly', dur: '8 weeks', note: 'After breakfast'),
      RxTemplateMedicine(name: 'Calcium Carbonate', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After meals'),
    ],
  ),
  RxTemplate(
    label: 'Obesity / Metabolic',
    icon: Icons.monitor_weight_outlined,
    color: _violet,
    notes: 'Target 5-10% weight loss in 6 months. 500 kcal/day deficit. Review in 4 weeks.',
    medicines: [
      RxTemplateMedicine(name: 'Metformin', strength: '500mg', freq: 'BD', dur: '30 days', note: 'After food'),
      RxTemplateMedicine(name: 'Vitamin B12', strength: '1500mcg', freq: 'OD', dur: '30 days', note: 'After breakfast'),
    ],
  ),
];
