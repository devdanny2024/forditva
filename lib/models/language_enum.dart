import 'dart:ui'; // For Locale

// Dutch/French/Spanish/Russian/Italian added as selectable options for the
// user-configurable "third language" (Settings > third language), which
// replaces English as the sole non-HU/DE slot in the translation pages.
enum Language {
  hungarian,
  german,
  english,
  dutch,
  french,
  spanish,
  russian,
  italian,
}

extension LanguageCode on Language {
  /// two‐letter code for external APIs:
  String get code => label;
}

extension LanguageExtension on Language {
  String get label {
    switch (this) {
      case Language.hungarian:
        return 'HU';
      case Language.german:
        return 'DE';
      case Language.english:
        return 'EN';
      case Language.dutch:
        return 'NL';
      case Language.french:
        return 'FR';
      case Language.spanish:
        return 'ES';
      case Language.russian:
        return 'RU';
      case Language.italian:
        return 'IT';
    }
  }

  String get placeholder {
    switch (this) {
      case Language.hungarian:
        return 'Mit szeretne ma lefordítani?';
      case Language.german:
        return 'Was möchten Sie heute übersetzen?';
      case Language.english:
        return 'What would you like to translate today?';
      case Language.dutch:
        return 'Wat wil je vandaag vertalen?';
      case Language.french:
        return "Que voulez-vous traduire aujourd'hui ?";
      case Language.spanish:
        return '¿Qué te gustaría traducir hoy?';
      case Language.russian:
        return 'Что вы хотите перевести сегодня?';
      case Language.italian:
        return 'Cosa vorresti tradurre oggi?';
    }
  }

  /// Full English language name, used inside Gemini prompts.
  String get fullName {
    switch (this) {
      case Language.hungarian:
        return 'Hungarian';
      case Language.german:
        return 'German';
      case Language.english:
        return 'English';
      case Language.dutch:
        return 'Dutch';
      case Language.french:
        return 'French';
      case Language.spanish:
        return 'Spanish';
      case Language.russian:
        return 'Russian';
      case Language.italian:
        return 'Italian';
    }
  }

  String get flagPath {
    switch (this) {
      case Language.hungarian:
        return 'assets/flags/HU_BW_LS.png';
      case Language.german:
        return 'assets/flags/DE_BW_LS.png';
      case Language.english:
        return 'assets/flags/EN_BW_LS.png';
      // Markus hasn't sent BW_LS-style card flags for these yet, only the
      // colored settings-selector flags (assets/flags/{CODE}_L.png). Reuse
      // those here so the cards render something instead of a missing
      // asset; swap to a dedicated _BW_LS file once he sends one.
      case Language.dutch:
        return 'assets/flags/NL_L.png';
      case Language.french:
        return 'assets/flags/FR_L.png';
      case Language.spanish:
        return 'assets/flags/ES_L.png';
      case Language.russian:
        return 'assets/flags/RU_L.png';
      case Language.italian:
        return 'assets/flags/IT_L.png';
    }
  }

}

/// Languages the user can pick in Settings as their "third language",
/// alongside the fixed Hungarian/German pair.
const List<Language> thirdLanguageOptions = [
  Language.english,
  Language.dutch,
  Language.french,
  Language.italian,
  Language.russian,
  Language.spanish,
];

List<Language> getInitialLangPair(Locale locale) {
  switch (locale.languageCode.toLowerCase()) {
    case 'hu':
      return [Language.hungarian, Language.german];
    case 'de':
      return [Language.german, Language.hungarian];
    case 'en':
    default:
      return [Language.english, Language.hungarian];
  }
}
