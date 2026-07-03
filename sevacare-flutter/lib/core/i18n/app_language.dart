/// Supported app languages. English is the default; the rest cover the
/// major South-Indian languages plus Hindi, shown with their native names
/// so every user can find their own language easily.
enum AppLanguage { en, hi, kn, te, ta, ml }

extension AppLanguageInfo on AppLanguage {
  /// Native name — what users see in the picker.
  String get nativeName => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.hi => 'हिन्दी',
        AppLanguage.kn => 'ಕನ್ನಡ',
        AppLanguage.te => 'తెలుగు',
        AppLanguage.ta => 'தமிழ்',
        AppLanguage.ml => 'മലയാളം',
      };

  /// English name shown as a secondary hint.
  String get englishName => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.hi => 'Hindi',
        AppLanguage.kn => 'Kannada',
        AppLanguage.te => 'Telugu',
        AppLanguage.ta => 'Tamil',
        AppLanguage.ml => 'Malayalam',
      };

  String get code => name;

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((l) => l.name == code,
          orElse: () => AppLanguage.en);
}
