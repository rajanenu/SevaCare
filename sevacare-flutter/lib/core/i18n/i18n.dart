import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'translations.dart';

export 'app_language.dart';
export 'translations.dart';

const _kLanguagePrefKey = 'app_language';

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.en) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLanguagePrefKey);
    if (saved != null && mounted) {
      state = AppLanguageInfo.fromCode(saved);
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguagePrefKey, lang.code);
  }
}

/// The user's preferred language, persisted across sessions.
final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>(
  (ref) => LanguageNotifier(),
);

/// Translate an English source string to the active language.
/// Falls back to the source text when no translation exists, so screens can
/// adopt this incrementally without ever breaking.
String tr(WidgetRef ref, String source) =>
    Translations.tr(ref.watch(languageProvider), source);
