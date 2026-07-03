/// Lightweight on-device symptom → specialty suggester.
///
/// Scores the free-text symptoms against a curated keyword map and returns
/// the best-matching specialties from the ones the hospital actually offers.
/// Kept as a pure function so future modules (QR booking form, IP-Staff
/// intake, tele-consult) can reuse it unchanged.
library;

class SpecialtySuggestion {
  final String specialty;
  final String matchedSymptom;
  final int score;

  const SpecialtySuggestion({
    required this.specialty,
    required this.matchedSymptom,
    required this.score,
  });
}

class SymptomSpecialtyEngine {
  SymptomSpecialtyEngine._();

  /// Keyword → canonical specialty. Longer/more specific phrases score higher.
  static const Map<String, List<String>> _keywords = {
    'General Physician': [
      'fever', 'cold', 'cough', 'body pain', 'body ache', 'weakness',
      'fatigue', 'headache', 'vomiting', 'nausea', 'flu', 'viral',
      'infection', 'chills', 'sore throat', 'tiredness', 'dizzy', 'dizziness',
    ],
    'Dentist': [
      'tooth', 'teeth', 'toothache', 'tooth pain', 'gum', 'gums', 'cavity',
      'dental', 'mouth ulcer', 'wisdom tooth', 'bad breath', 'jaw pain',
      'bleeding gums', 'sensitive teeth',
    ],
    'Pediatrician': [
      'child', 'baby', 'infant', 'kid', 'newborn', 'vaccination', 'vaccine',
      'child fever', 'growth', 'not eating', 'crying', 'diaper',
    ],
    'Cardiology': [
      'chest pain', 'heart', 'palpitation', 'breathless', 'shortness of breath',
      'high bp', 'blood pressure', 'chest tightness', 'irregular heartbeat',
    ],
    'Dermatology': [
      'skin', 'rash', 'itching', 'itch', 'acne', 'pimple', 'hair fall',
      'hair loss', 'allergy', 'eczema', 'psoriasis', 'dandruff', 'dark spots',
      'nail', 'fungal',
    ],
    'Orthopedics': [
      'bone', 'joint', 'knee', 'back pain', 'neck pain', 'shoulder',
      'fracture', 'sprain', 'arthritis', 'hip', 'ankle', 'wrist',
      'joint pain', 'spine', 'sports injury',
    ],
    'ENT': [
      'ear', 'nose', 'throat', 'hearing', 'sinus', 'tonsil', 'snoring',
      'ear pain', 'blocked nose', 'nose bleed', 'voice', 'vertigo',
    ],
    'Gynecology': [
      'pregnancy', 'pregnant', 'period', 'menstrual', 'pcod', 'pcos',
      'irregular periods', 'white discharge', 'fertility', 'menopause',
    ],
    'Neurology': [
      'migraine', 'seizure', 'fits', 'numbness', 'tingling', 'memory loss',
      'tremor', 'paralysis', 'stroke', 'severe headache',
    ],
    'Ophthalmology': [
      'eye', 'vision', 'blurred vision', 'red eye', 'watering eyes',
      'eye pain', 'spectacles', 'cataract', 'itchy eyes',
    ],
    'Gastroenterology': [
      'stomach', 'stomach pain', 'acidity', 'gas', 'constipation',
      'diarrhea', 'loose motion', 'indigestion', 'ulcer', 'liver',
      'jaundice', 'piles', 'abdominal pain',
    ],
    'Psychiatry': [
      'anxiety', 'depression', 'stress', 'sleep problem', 'insomnia',
      'panic', 'mood', 'addiction',
    ],
    'Urology': [
      'urine', 'urination', 'kidney stone', 'burning urination',
      'frequent urination', 'kidney',
    ],
    'Pulmonology': [
      'asthma', 'wheezing', 'breathing difficulty', 'lung', 'tb',
      'long cough', 'chronic cough',
    ],
  };

  /// Suggests up to [maxResults] specialties for the symptom text, limited to
  /// the specialties this hospital actually offers (case/spacing tolerant).
  static List<SpecialtySuggestion> suggest(
    String symptomsText,
    List<String> availableSpecialties, {
    int maxResults = 2,
  }) {
    final text = symptomsText.toLowerCase().trim();
    if (text.length < 3) return const [];

    final scores = <String, SpecialtySuggestion>{};
    _keywords.forEach((specialty, words) {
      var score = 0;
      var bestMatch = '';
      for (final w in words) {
        if (text.contains(w)) {
          // Multi-word phrases are stronger signals than single words
          final gain = w.contains(' ') ? 3 : 2;
          score += gain;
          if (w.length > bestMatch.length) bestMatch = w;
        }
      }
      if (score > 0) {
        scores[specialty] = SpecialtySuggestion(
          specialty: specialty,
          matchedSymptom: bestMatch,
          score: score,
        );
      }
    });

    if (scores.isEmpty) return const [];

    // Map canonical names onto the tenant's own specialty labels
    final results = <SpecialtySuggestion>[];
    final ranked = scores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    for (final suggestion in ranked) {
      final matched = _matchAvailable(suggestion.specialty, availableSpecialties);
      if (matched != null) {
        results.add(SpecialtySuggestion(
          specialty: matched,
          matchedSymptom: suggestion.matchedSymptom,
          score: suggestion.score,
        ));
      }
      if (results.length >= maxResults) break;
    }
    return results;
  }

  static String? _matchAvailable(String canonical, List<String> available) {
    final c = canonical.toLowerCase();
    for (final a in available) {
      final al = a.toLowerCase();
      if (al == c || al.contains(c) || c.contains(al)) return a;
    }
    // Common aliases
    const aliases = {
      'dentist': ['dental', 'dentistry'],
      'pediatrician': ['pediatrics', 'paediatrics', 'child specialist'],
      'gynecology': ['gynaecology', 'obstetrics'],
      'orthopedics': ['orthopaedics', 'ortho'],
      'general physician': ['general medicine', 'physician', 'gp'],
    };
    final aliasList = aliases[c] ?? const <String>[];
    for (final a in available) {
      final al = a.toLowerCase();
      for (final alias in aliasList) {
        if (al.contains(alias) || alias.contains(al)) return a;
      }
    }
    return null;
  }
}
