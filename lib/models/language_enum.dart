enum Language { hungarian, german, english }

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
    }
  }

  Language next(Language other) {
    final list = Language.values;
    var idx = list.indexOf(this);
    do {
      idx = (idx + 1) % list.length;
    } while (list[idx] == other);
    return list[idx];
  }
}
