// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get title => 'forditva';

  @override
  String get menu => 'Menü';

  @override
  String get conversation => 'Gespräch';

  @override
  String get learningList => 'Lernliste';

  @override
  String get favorites => 'Favoriten';

  @override
  String get history => 'Verlauf';

  @override
  String get helpSupport => 'Hilfe & Unterstützung';

  @override
  String get settings => 'Einstellungen';

  @override
  String get licenseCredit => 'Lizenz & Credits';

  @override
  String get searchHint => 'Suchen…';

  @override
  String get inputPlaceholder => 'Was möchtest du heute übersetzen?';

  @override
  String get outputPlaceholder => 'Die Übersetzung erscheint hier.';

  @override
  String get documentMode => 'Dokument';

  @override
  String get imageMode => 'Bild';

  @override
  String get copyToClipboard => 'In die Zwischenablage kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get searchFavorites => 'Favoriten durchsuchen...';

  @override
  String get noFavoritesFound => 'Keine Favoriten gefunden.';

  @override
  String get removedFromFavorites => 'Aus den Favoriten entfernt';

  @override
  String get searchHistory => 'Verlauf durchsuchen...';

  @override
  String get noHistoryFound => 'Kein Verlauf gefunden.';

  @override
  String get delete => 'Löschen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Fertig';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get profileAndSettings => 'Profil und Einstellungen';

  @override
  String get appSettings => 'App-Einstellungen';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get thirdLanguage => 'dritte Sprache (neben HU und DE)';

  @override
  String get saveHistory => 'Verlauf speichern';

  @override
  String get clearEntireHistory => 'Gesamten Verlauf löschen';

  @override
  String get clearHistoryConfirm =>
      'Möchtest du wirklich den gesamten Übersetzungsverlauf löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get historyCleared => 'Verlauf gelöscht';

  @override
  String get credits => 'Guthaben';

  @override
  String get howItWorks => 'So funktioniert es ...';

  @override
  String get howItWorksBody =>
      'Diese App lebt vom Gemeinschaftsgeist! Einen Guthabencode erhältst du über dein Benutzerkonto auf wir-in-ungarn.hu. Hier gibt es keinen kommerziellen Checkout — Guthaben verdienst du dir ausschließlich durch dein Engagement, sei es durch das Beitragen von Inhalten oder das Helfen in der Community. Deine Teilnahme ist unsere Währung!';

  @override
  String get currentStatus => 'Aktueller Status';

  @override
  String get codeForFillingCredits => 'Code zum Aufladen';

  @override
  String get pleaseEnterCode => 'Bitte gib einen Code ein';

  @override
  String get codeSubmitted => 'Code übermittelt';

  @override
  String get codeRedeemed => 'Code eingelöst';

  @override
  String get codeInvalid =>
      'Dieser Code ist ungültig oder wurde bereits verwendet';

  @override
  String get codeRateLimited =>
      'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut';

  @override
  String get codeNetworkError =>
      'Keine Verbindung. Bitte prüfe deine Internetverbindung und versuche es erneut';

  @override
  String get codeUnavailable => 'Das Aufladen ist gerade nicht verfügbar';

  @override
  String get organizeCredits => 'Guthaben verwalten';

  @override
  String get gotoProfile => 'Zu meinem Profil auf wir-in-ungarn.hu';

  @override
  String get couldNotOpenPage => 'Seite konnte nicht geöffnet werden';

  @override
  String get languageLearning => 'Sprachenlernen';

  @override
  String get levelDescription =>
      'Stelle dein aktuelles Niveau von 01 (absoluter Anfänger) bis 99 (solide Mittelstufe/B1) ein. Dies passt den Wortschatz und die Grammatikerklärungen des KI-Tutors genau an deine Bedürfnisse an.';

  @override
  String get levelTip =>
      'Tipp: Du kannst das Niveau jederzeit direkt im Tutor dynamisch anpassen.';

  @override
  String get myCurrentLevel => 'Mein aktuelles Niveau';

  @override
  String get ttsFailed => 'Sprachwiedergabe fehlgeschlagen';

  @override
  String get recordingFailed => 'Aufnahme fehlgeschlagen.';

  @override
  String get transcriptionFailed => 'Transkription fehlgeschlagen';

  @override
  String get couldNotTranscribe =>
      'Audio konnte nicht transkribiert werden. Bitte versuche es erneut.';

  @override
  String get pleaseMakeRecording => 'Bitte nimm etwas auf';

  @override
  String get wrongLanguage => 'Falsche Sprache';

  @override
  String get wrongLanguageBody => 'Bitte gib die richtige Sprache ein.';

  @override
  String get editTextHint => 'Text bearbeiten...';

  @override
  String get imageNotClear => 'Bild nicht klar';

  @override
  String get imageNotClearBody =>
      'Das Bild ist nicht klar genug, damit die KI es lesen kann. Bitte versuche es mit einem anderen Bild.';

  @override
  String get serviceUnavailable =>
      'Der Dienst ist vorübergehend nicht verfügbar. Bitte versuche es später erneut.';

  @override
  String get speakCorrectLanguage => 'Bitte sprich die richtige Sprache.';

  @override
  String langMismatch(Object detected, Object selected) {
    return 'Erkannte Sprache ist $detected, aber deine ausgewählte Eingabe ist $selected. Möchtest du die Eingabesprache wechseln?';
  }

  @override
  String get translateAction => 'Übersetzen';

  @override
  String get documentPlaceholder =>
      'Hier tippen oder aus Zwischenablage einfügen.';

  @override
  String get imagePickerLine1 => 'KLICKE, UM EIN FOTO ZU MACHEN, ODER';

  @override
  String get imagePickerLink => 'LADE EINS HOCH';

  @override
  String get imagePickerLine2 => ' VON DEINEM GERÄT.';

  @override
  String get cropInstruction =>
      'Forme mit deinem Finger den gewünschten Bereich';

  @override
  String get errorTitle => 'Verbindung nicht möglich';

  @override
  String get errorMessage =>
      'Wir konnten den Übersetzungsdienst nicht erreichen. Bitte prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get wiuEmptyTitle => 'Guthaben aufgebraucht';

  @override
  String get wiuEmptyBody =>
      'Dein WIU-Guthaben ist leer. Bitte lade auf wir-in-ungarn.hu auf, um weiter übersetzen zu können.';

  @override
  String get wiuLowBody =>
      'Dein WIU-Guthaben wird knapp. Lade bald auf wir-in-ungarn.hu auf.';
}
