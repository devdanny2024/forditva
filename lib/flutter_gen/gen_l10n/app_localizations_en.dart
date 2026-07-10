// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'forditva';

  @override
  String get menu => 'Menu';

  @override
  String get conversation => 'Conversation';

  @override
  String get learningList => 'Learning List';

  @override
  String get favorites => 'Favorites';

  @override
  String get history => 'History';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get settings => 'Settings';

  @override
  String get licenseCredit => 'License & Credits';

  @override
  String get searchHint => 'Search...';

  @override
  String get inputPlaceholder => 'What would you like to translate today?';

  @override
  String get outputPlaceholder => 'Translation will appear here.';

  @override
  String get documentMode => 'Document';

  @override
  String get imageMode => 'Image';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get searchFavorites => 'Search favorites...';

  @override
  String get noFavoritesFound => 'No favorites found.';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get searchHistory => 'Search history...';

  @override
  String get noHistoryFound => 'No history found.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Done';

  @override
  String get gotIt => 'Got it';

  @override
  String get profileAndSettings => 'Profile and Settings';

  @override
  String get appSettings => 'App Settings';

  @override
  String get appLanguage => 'App Language';

  @override
  String get thirdLanguage => 'third language (beside HU and DE)';

  @override
  String get saveHistory => 'Save History';

  @override
  String get clearEntireHistory => 'Clear Entire History';

  @override
  String get clearHistoryConfirm =>
      'Are you sure you want to delete your entire translation history? This action cannot be undone.';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get credits => 'Credits';

  @override
  String get howItWorks => 'How it works ...';

  @override
  String get howItWorksBody =>
      'This app is powered by community spirit! You can get a credit code via your user account on wir-in-ungarn.hu. There is no commercial checkout here — credits are earned solely through your engagement, whether by contributing content or helping out in the community. Your participation is our currency!';

  @override
  String get currentStatus => 'Current Status';

  @override
  String get codeForFillingCredits => 'Code for recharging';

  @override
  String get pleaseEnterCode => 'Please enter a code';

  @override
  String get codeSubmitted => 'Code submitted';

  @override
  String get codeRedeemed => 'Code redeemed';

  @override
  String get codeInvalid => 'This code is invalid or has already been used';

  @override
  String get codeRateLimited =>
      'Too many attempts. Please wait a moment and try again';

  @override
  String get codeNetworkError =>
      'No connection. Please check your internet and try again';

  @override
  String get codeUnavailable => 'Recharging is not available right now';

  @override
  String get organizeCredits => 'Manage Credits';

  @override
  String get gotoProfile => 'Go to my profile on wir-in-ungarn.hu';

  @override
  String get couldNotOpenPage => 'Could not open the page';

  @override
  String get languageLearning => 'Language Learning';

  @override
  String get levelDescription =>
      'Set your current level from 01 (absolute beginner) to 99 (solid intermediate/B1). This tailors the AI Tutor\'s vocabulary and grammar explanations exactly to your needs.';

  @override
  String get levelTip =>
      'Tip: You can dynamically adjust your level directly inside the Tutor at any time.';

  @override
  String get myCurrentLevel => 'My current Level';

  @override
  String get ttsFailed => 'Speech playback failed';

  @override
  String get recordingFailed => 'Recording failed.';

  @override
  String get transcriptionFailed => 'Transcription failed';

  @override
  String get couldNotTranscribe =>
      'Couldn\'t transcribe audio. Please try again.';

  @override
  String get pleaseMakeRecording => 'Please make a recording';

  @override
  String get wrongLanguage => 'Wrong Language';

  @override
  String get wrongLanguageBody =>
      'Please select or enter the correct language.';

  @override
  String get editTextHint => 'Edit text...';

  @override
  String get imageNotClear => 'Image Not Clear';

  @override
  String get imageNotClearBody =>
      'The image is not clear enough for the AI to read. Please try another image.';

  @override
  String get serviceUnavailable =>
      'The service is temporarily unavailable. Please try again later.';

  @override
  String get speakCorrectLanguage => 'Please speak the correct language.';

  @override
  String langMismatch(Object detected, Object selected) {
    return 'Detected language is $detected but your selected input is $selected. Would you like to switch the input language?';
  }

  @override
  String get translateAction => 'Translate';

  @override
  String get documentPlaceholder =>
      'Type the text here or paste it from the clipboard.';

  @override
  String get imagePickerLine1 => 'CLICK TO TAKE A PHOTO OR';

  @override
  String get imagePickerLink => 'LOAD UP FROM';

  @override
  String get imagePickerLine2 => ' YOUR DEVICE.';

  @override
  String get cropInstruction => 'Shape with your finger the required area';

  @override
  String get errorTitle => 'Connection problem';

  @override
  String get errorMessage =>
      'We can\'t reach the translation service right now. Please check your internet connection and try again.';

  @override
  String get wiuEmptyTitle => 'Out of credit';

  @override
  String get wiuEmptyBody =>
      'Your WIU balance is empty. Please top up on wir-in-ungarn.hu to keep translating.';

  @override
  String get wiuLowBody =>
      'Your WIU balance is getting low. Consider topping up soon on wir-in-ungarn.hu.';
}
