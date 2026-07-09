import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Text-to-speech via **Google Cloud TTS** with a NATIVE voice per language
/// (German / Hungarian / English). The previous Gemini TTS used English-centric
/// personas, which made German sound foreign-accented; native de-DE voices fix
/// that. Uses the same Google API key as speech-to-text.
///
/// The class name is kept as `GeminiTtsService` so the existing call sites and
/// imports don't need to change.
class GeminiTtsService {
  String get _apiKey => dotenv.env['GOOGLE_STT_KEY']!;

  // Native voice per language: [languageCode, voiceName]. Every selectable
  // language (HU/DE + the third-language options) needs an entry, otherwise
  // its text was read with the default (German/Hungarian) voice.
  static const Map<String, List<String>> _voices = {
    'DE': ['de-DE', 'de-DE-Neural2-B'],
    'HU': ['hu-HU', 'hu-HU-Wavenet-A'],
    'EN': ['en-US', 'en-US-Neural2-D'],
    'FR': ['fr-FR', 'fr-FR-Neural2-F'],
    'ES': ['es-ES', 'es-ES-Neural2-A'],
    'IT': ['it-IT', 'it-IT-Neural2-A'],
    'NL': ['nl-NL', 'nl-NL-Wavenet-F'],
    'RU': ['ru-RU', 'ru-RU-Wavenet-A'],
  };

  /// Detects the target language. Prefers an explicit [langCode]; otherwise
  /// parses the language out of the [instructions] the callers pass.
  String _resolveLang(String? langCode, String? instructions) {
    final explicit = (langCode ?? '').toUpperCase();
    if (_voices.containsKey(explicit)) return explicit;
    final i = (instructions ?? '').toLowerCase();
    if (i.contains('german') || i.contains('deutsch')) return 'DE';
    if (i.contains('hungarian') || i.contains('magyar')) return 'HU';
    if (i.contains('english')) return 'EN';
    if (i.contains('french') || i.contains('français')) return 'FR';
    if (i.contains('spanish') || i.contains('español')) return 'ES';
    if (i.contains('italian') || i.contains('italiano')) return 'IT';
    if (i.contains('dutch') || i.contains('nederlands')) return 'NL';
    if (i.contains('russian') || i.contains('русск')) return 'RU';
    return 'DE';
  }

  Future<File> synthesizeSpeech({
    required String text,
    String voice = '', // ignored; kept for call-site compatibility
    String model = '', // ignored; kept for call-site compatibility
    String format = 'mp3',
    String? instructions,
    String? langCode,
  }) async {
    final code = _resolveLang(langCode, instructions);
    final v = _voices[code]!;

    final url = Uri.parse(
      'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {'languageCode': v[0], 'name': v[1]},
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Google TTS failed: ${response.statusCode} ${response.body}',
      );
    }

    final audioContent = jsonDecode(response.body)['audioContent'] as String?;
    if (audioContent == null) {
      throw Exception('Google TTS returned no audio: ${response.body}');
    }

    final bytes = base64Decode(audioContent);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
