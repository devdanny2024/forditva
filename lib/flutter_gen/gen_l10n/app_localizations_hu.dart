// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get title => 'forditva';

  @override
  String get menu => 'Menü';

  @override
  String get conversation => 'Beszélgetés';

  @override
  String get learningList => 'Tanulási lista';

  @override
  String get favorites => 'Kedvencek';

  @override
  String get history => 'Előzmények';

  @override
  String get helpSupport => 'Súgó & Támogatás';

  @override
  String get settings => 'Beállítások';

  @override
  String get licenseCredit => 'Licenc & Kredit';

  @override
  String get searchHint => 'Keresés…';

  @override
  String get inputPlaceholder => 'Mit szeretnél ma lefordítani?';

  @override
  String get outputPlaceholder => 'A fordítás itt fog megjelenni.';

  @override
  String get documentMode => 'Dokumentum';

  @override
  String get imageMode => 'Kép';

  @override
  String get copyToClipboard => 'Vágólapra másolás';

  @override
  String get copiedToClipboard => 'Vágólapra másolva';

  @override
  String get searchFavorites => 'Keresés a kedvencek között...';

  @override
  String get noFavoritesFound => 'Nincsenek kedvencek.';

  @override
  String get removedFromFavorites => 'Eltávolítva a kedvencekből';

  @override
  String get searchHistory => 'Előzmények keresése...';

  @override
  String get noHistoryFound => 'Nincsenek előzmények.';

  @override
  String get delete => 'Törlés';

  @override
  String get cancel => 'Mégse';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Kész';

  @override
  String get gotIt => 'Értem';

  @override
  String get profileAndSettings => 'Profil és beállítások';

  @override
  String get appSettings => 'Alkalmazás beállításai';

  @override
  String get appLanguage => 'Alkalmazás nyelve';

  @override
  String get thirdLanguage => 'harmadik nyelv (a HU és a DE mellett)';

  @override
  String get saveHistory => 'Előzmények mentése';

  @override
  String get clearEntireHistory => 'Teljes előzmény törlése';

  @override
  String get clearHistoryConfirm =>
      'Biztosan törlöd a teljes fordítási előzményt? Ez a művelet nem vonható vissza.';

  @override
  String get historyCleared => 'Előzmények törölve';

  @override
  String get credits => 'Kreditek';

  @override
  String get howItWorks => 'Hogyan működik ...';

  @override
  String get howItWorksBody =>
      'Ezt az alkalmazást a közösségi szellem hajtja! Kreditkódot a wir-in-ungarn.hu oldalon, a felhasználói fiókodon keresztül szerezhetsz. Itt nincs kereskedelmi fizetés — a krediteket kizárólag a részvételeddel tudod megszerezni, akár tartalom hozzáadásával, akár a közösség segítésével. A Te részvételed a mi pénznemünk!';

  @override
  String get currentStatus => 'Jelenlegi állapot';

  @override
  String get codeForFillingCredits => 'Kód a feltöltéshez';

  @override
  String get pleaseEnterCode => 'Kérjük, adj meg egy kódot';

  @override
  String get codeSubmitted => 'Kód elküldve';

  @override
  String get codeRedeemed => 'Kód beváltva';

  @override
  String get codeInvalid => 'Ez a kód érvénytelen, vagy már felhasználták';

  @override
  String get codeRateLimited =>
      'Túl sok próbálkozás. Kérlek, várj egy kicsit, és próbáld újra';

  @override
  String get codeNetworkError =>
      'Nincs kapcsolat. Kérlek, ellenőrizd az internetkapcsolatodat, és próbáld újra';

  @override
  String get codeUnavailable => 'A feltöltés jelenleg nem érhető el';

  @override
  String get organizeCredits => 'Kreditek kezelése';

  @override
  String get gotoProfile => 'Profilom a wir-in-ungarn.hu oldalon';

  @override
  String get couldNotOpenPage => 'Az oldal nem nyitható meg';

  @override
  String get languageLearning => 'Nyelvtanulás';

  @override
  String get levelDescription =>
      'Állítsd be a jelenlegi szintedet 01-től (abszolút kezdő) 99-ig (stabil középhaladó/B1). Ez pontosan a te igényeidhez igazítja az MI-oktató szókincsét és nyelvtani magyarázatait.';

  @override
  String get levelTip =>
      'Tipp: A szintet bármikor dinamikusan módosíthatod közvetlenül az oktatóban.';

  @override
  String get myCurrentLevel => 'Jelenlegi szintem';

  @override
  String get ttsFailed => 'A hanglejátszás sikertelen';

  @override
  String get recordingFailed => 'A felvétel sikertelen.';

  @override
  String get transcriptionFailed => 'Az átírás sikertelen';

  @override
  String get couldNotTranscribe =>
      'Nem sikerült átírni a hangot. Próbáld újra.';

  @override
  String get pleaseMakeRecording => 'Kérjük, készíts egy felvételt';

  @override
  String get wrongLanguage => 'Rossz nyelv';

  @override
  String get wrongLanguageBody => 'Kérjük, a megfelelő nyelvet add meg.';

  @override
  String get editTextHint => 'Szöveg szerkesztése...';

  @override
  String get imageNotClear => 'A kép nem tiszta';

  @override
  String get imageNotClearBody =>
      'A kép nem elég tiszta ahhoz, hogy az MI elolvassa. Kérjük, próbálj egy másik képet.';

  @override
  String get serviceUnavailable =>
      'A szolgáltatás átmenetileg nem érhető el. Kérjük, próbáld újra később.';

  @override
  String get speakCorrectLanguage => 'Kérjük, a megfelelő nyelven beszélj.';

  @override
  String langMismatch(Object detected, Object selected) {
    return 'Az észlelt nyelv $detected, de a kiválasztott bemenet $selected. Szeretnéd átváltani a bemeneti nyelvet?';
  }

  @override
  String get translateAction => 'Fordítás';

  @override
  String get documentPlaceholder =>
      'Írja be ide a szöveget, vagy illessze be a vágólapról.';

  @override
  String get imagePickerLine1 => 'KATTINTS FÉNYKÉPKÉSZÍTÉSHEZ VAGY';

  @override
  String get imagePickerLink => 'TÖLTS FEL EGYET';

  @override
  String get imagePickerLine2 => ' AZ ESZKÖZÖDRŐL.';

  @override
  String get cropInstruction => 'Rajzold körbe ujjaddal a kívánt területet';

  @override
  String get errorTitle => 'Kapcsolódási probléma';

  @override
  String get errorMessage =>
      'Nem értük el a fordítóprogramot. Kérlek, ellenőrizd az internetkapcsolatodat, és próbáld meg újra.';

  @override
  String get wiuEmptyTitle => 'Nincs egyenleg';

  @override
  String get wiuEmptyBody =>
      'Kiürült a WIU egyenleged. Kérlek, töltsd fel a wir-in-ungarn.hu oldalon, hogy tovább tudj fordítani.';

  @override
  String get wiuLowBody =>
      'Fogy a WIU egyenleged. Töltsd fel hamarosan a wir-in-ungarn.hu oldalon.';
}
