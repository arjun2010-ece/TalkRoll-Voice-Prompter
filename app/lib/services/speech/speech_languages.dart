/// The languages Voice and Audio mode can be asked to recognise, and how the one to use is chosen.
///
/// The list is the reference app's (`kw2`); the detector is a port of its `rg3.e0` / `rg3.g0`: it reads the first
/// 2000 characters of the script, counts letters per writing system and, for Latin text, looks for letters only
/// some languages use. A script it can't place is English, as in the reference.
library;

/// A language tag the platform recognisers take (`en-US`, `pt-BR`, ...) and the name shown for it.
class SpeechLanguage {
  const SpeechLanguage(this.tag, this.name);
  final String tag;
  final String name;

  /// The language part of [tag] (`pt` for `pt-BR`).
  String get code => tag.split('-').first;
}

/// The setting value that picks the language from the script.
const autoSpeechLanguage = 'auto';

const defaultSpeechLanguage = 'en-US';

/// English first, then the rest by name, as the reference lists them. Thai is left out until its text can be split
/// into words (it has no spaces, and only Chinese and Japanese are split per character).
final List<SpeechLanguage> speechLanguages = (() {
  const all = [
    SpeechLanguage('en-US', 'English (United States)'),
    SpeechLanguage('en-GB', 'English (United Kingdom)'),
    SpeechLanguage('en-AU', 'English (Australia)'),
    SpeechLanguage('en-IN', 'English (India)'),
    SpeechLanguage('ar-SA', 'Arabic (Saudi Arabia)'),
    SpeechLanguage('bg-BG', 'Bulgarian'),
    SpeechLanguage('ca-ES', 'Catalan'),
    SpeechLanguage('cs-CZ', 'Czech'),
    SpeechLanguage('da-DK', 'Danish'),
    SpeechLanguage('de-DE', 'German'),
    SpeechLanguage('el-GR', 'Greek'),
    SpeechLanguage('es-ES', 'Spanish (Spain)'),
    SpeechLanguage('es-MX', 'Spanish (Mexico)'),
    SpeechLanguage('es-US', 'Spanish (United States)'),
    SpeechLanguage('fi-FI', 'Finnish'),
    SpeechLanguage('fr-CA', 'French (Canada)'),
    SpeechLanguage('fr-FR', 'French (France)'),
    SpeechLanguage('he-IL', 'Hebrew'),
    SpeechLanguage('hi-IN', 'Hindi'),
    SpeechLanguage('hr-HR', 'Croatian'),
    SpeechLanguage('hu-HU', 'Hungarian'),
    SpeechLanguage('id-ID', 'Indonesian'),
    SpeechLanguage('it-IT', 'Italian'),
    SpeechLanguage('ja-JP', 'Japanese'),
    SpeechLanguage('ko-KR', 'Korean'),
    SpeechLanguage('ms-MY', 'Malay'),
    SpeechLanguage('nb-NO', 'Norwegian Bokmål'),
    SpeechLanguage('nl-NL', 'Dutch'),
    SpeechLanguage('pl-PL', 'Polish'),
    SpeechLanguage('pt-BR', 'Portuguese (Brazil)'),
    SpeechLanguage('pt-PT', 'Portuguese (Portugal)'),
    SpeechLanguage('ro-RO', 'Romanian'),
    SpeechLanguage('ru-RU', 'Russian'),
    SpeechLanguage('sk-SK', 'Slovak'),
    SpeechLanguage('sl-SI', 'Slovenian'),
    SpeechLanguage('sv-SE', 'Swedish'),
    SpeechLanguage('tr-TR', 'Turkish'),
    SpeechLanguage('uk-UA', 'Ukrainian'),
    SpeechLanguage('vi-VN', 'Vietnamese'),
    SpeechLanguage('yue-Hant-HK', 'Cantonese (Hong Kong)'),
    SpeechLanguage('zh-CN', 'Chinese (Simplified)'),
    SpeechLanguage('zh-TW', 'Chinese (Traditional)'),
  ];
  return [all.first, ...(all.skip(1).toList()..sort((a, b) => a.name.compareTo(b.name)))];
})();

/// The name shown for [tag] (the tag itself when it isn't in the list).
String speechLanguageName(String tag) {
  if (tag == autoSpeechLanguage) return 'Automatic';
  for (final l in speechLanguages) {
    if (l.tag == tag) return l.name;
  }
  return tag;
}

/// Whether [a] and [b] are the same language for the "different language" question: the same language code, and for
/// Chinese the same writing (Simplified or Traditional).
bool sameSpeechLanguage(String a, String b) {
  String code(String t) => t.replaceAll('_', '-').split('-').first.toLowerCase();
  if (code(a) != code(b)) return false;
  if (code(a) != 'zh') return true;
  bool traditional(String t) => const {'zh-tw', 'zh-hk', 'zh-mo'}.contains(_key(t)) || t.contains('Hant');
  return traditional(a) == traditional(b);
}

/// [tag] lowercased, `_` as `-`, without a script subtag (`yue-Hant-HK` -> `yue-hk`), for comparing tags
/// from different sources.
String _key(String tag) {
  final parts = tag.replaceAll('_', '-').toLowerCase().split('-');
  return parts.length == 3 && parts[1].length == 4 ? '${parts[0]}-${parts[2]}' : parts.join('-');
}

/// Whether the language tag [a] is the same as [b], ignoring case, `_` and a script subtag.
bool sameSpeechTag(String a, String b) => _key(a) == _key(b);

/// The languages of [all] the platform reports in [supported]; every one when it reports none (older Android).
List<SpeechLanguage> supportedSpeechLanguages(Iterable<String> supported) {
  final keys = {for (final s in supported) _key(s)};
  if (keys.isEmpty) return speechLanguages;
  return [for (final l in speechLanguages) if (keys.contains(_key(l.tag))) l];
}

/// The tag to recognise: [setting] when it names a language, otherwise the language of [script] (`auto`).
/// [detected] is the platform's own reading of the script (Apple's language recogniser, see
/// [languageFromNaturalLanguage]); without it the script is read by [detectScriptLanguage].
/// [deviceTag] only chooses between the regional variants of a detected language (a `pt-PT` phone gets
/// `pt-PT` for a Portuguese script); [supported] (the tags the device can recognise, if it says) limits the choice.
///
/// With [detected] (Apple) the tag is one the device itself lists, as in the macOS reference: any region of the
/// language, whether or not it is in [speechLanguages], and `en-US` when the device has none.
String resolveSpeechLanguage({
  required String setting,
  required String script,
  required String deviceTag,
  String? detected,
  Iterable<String> supported = const [],
}) {
  if (setting != autoSpeechLanguage) return setting;
  final found = detected != null ? languageFromNaturalLanguage(detected) : detectScriptLanguage(script);
  if (found == null) return defaultSpeechLanguage;
  if (detected != null && supported.isNotEmpty) return _deviceVariantOf(found, deviceTag, supported);
  return _variantOf(found, deviceTag, supported);
}

/// The macOS reference's choice (`FUN_10018a2f0`): among the [supported] tags of [found]'s language, the one equal to
/// the device's tag (not for English, Chinese or Cantonese, whose regions are not a preference), else `en-US`, else
/// [found], else the first by name; `en-US` when the device lists none.
String _deviceVariantOf(String found, String deviceTag, Iterable<String> supported) {
  final code = found.split('-').first;
  final variants = [
    for (final s in supported)
      if (s.replaceAll('_', '-').split('-').first == code) s.replaceAll('_', '-'),
  ]..sort();
  final plain = code != 'en' && code != 'zh' && code != 'yue';
  // Traditional Chinese: Taiwan, then Hong Kong.
  for (final want in [if (plain) deviceTag, defaultSpeechLanguage, found, if (found == 'zh-TW') 'zh-HK']) {
    for (final v in variants) {
      if (sameSpeechTag(v, want)) return v;
    }
  }
  return variants.isEmpty ? defaultSpeechLanguage : variants.first;
}

/// The list tag for a language code from Apple's language recogniser (`fr`, `zh-Hans`, `yue`, `no`); null when
/// we don't list that language.
String? languageFromNaturalLanguage(String code) {
  switch (code) {
    case 'zh-Hans':
      return 'zh-CN';
    case 'zh-Hant':
      return 'zh-TW';
    case 'yue':
      return 'yue-Hant-HK';
    case 'no':
      return 'nb-NO';
  }
  final language = code.split('-').first;
  // The region a bare language code stands for, where the list's first entry by name is another one.
  final main = {'es': 'es-ES', 'fr': 'fr-FR', 'pt': 'pt-BR'}[language];
  if (main != null) return main;
  for (final l in speechLanguages) {
    if (l.code == language) return l.tag;
  }
  return null;
}

/// Reference `rg3.g0`: among the listed variants of [detected]'s language, the one equal to the device's tag (not for
/// English), else `en-US`, else the detected one itself, else the first.
String _variantOf(String detected, String deviceTag, Iterable<String> supported) {
  final code = detected.split('-').first;
  final keys = {for (final s in supported) _key(s)};
  final variants = [for (final l in speechLanguages) if (l.code == code && (keys.isEmpty || keys.contains(_key(l.tag)))) l.tag];
  // English stays en-US whatever the device region (an en-IN phone reading English is not asking for en-IN).
  for (final want in [if (code != 'en') deviceTag, defaultSpeechLanguage, detected]) {
    for (final v in variants) {
      if (sameSpeechTag(v, want)) return v;
    }
  }
  return variants.isEmpty ? defaultSpeechLanguage : variants.first;
}

/// Reference `rg3.e0`: the language of [script] from its writing system, or from letters only some Latin-script
/// languages use; null when it can't tell (plain Latin text).
String? detectScriptLanguage(String script) {
  final text = script.length > 2000 ? script.substring(0, 2000) : script;
  var letters = 0, latin = 0, cyrillic = 0, han = 0, kana = 0, hangul = 0, arabic = 0, hebrew = 0, greek = 0, thai = 0, devanagari = 0;
  final isLetter = RegExp(r'\p{L}', unicode: true);
  for (final rune in text.runes) {
    final c = String.fromCharCode(rune);
    if (!isLetter.hasMatch(c)) continue;
    letters++;
    if (rune < 0x250 || (rune >= 0x1E00 && rune < 0x1F00)) {
      latin++;
    } else if (rune >= 0x400 && rune < 0x530) {
      cyrillic++;
    } else if ((rune >= 0x4E00 && rune < 0xA000) || (rune >= 0x3400 && rune < 0x4DC0) || (rune >= 0x20000 && rune < 0x2FA20)) {
      han++;
    } else if (rune >= 0x3040 && rune < 0x3100) {
      kana++;
    } else if ((rune >= 0xAC00 && rune < 0xD7B0) || (rune >= 0x1100 && rune < 0x1200)) {
      hangul++;
    } else if ((rune >= 0x600 && rune < 0x700) || (rune >= 0x750 && rune < 0x780)) {
      arabic++;
    } else if (rune >= 0x590 && rune < 0x600) {
      hebrew++;
    } else if (rune >= 0x370 && rune < 0x400) {
      greek++;
    } else if (rune >= 0xE00 && rune < 0xE80) {
      thai++;
    } else if (rune >= 0x900 && rune < 0x980) {
      devanagari++;
    }
  }
  if (letters == 0) return null;
  final half = letters ~/ 2;
  if (cyrillic > half) return text.contains(RegExp('[іїєґІЇЄҐ]')) ? 'uk-UA' : 'ru-RU';
  if (kana > 0 && kana + han > half) return 'ja-JP';
  if (han > half) return 'zh-CN';
  if (hangul > half) return 'ko-KR';
  if (arabic > half) return 'ar-SA';
  if (hebrew > half) return 'he-IL';
  if (greek > half) return 'el-GR';
  if (thai > half) return 'th-TH';
  if (devanagari > half) return 'hi-IN';
  if (latin <= half) return null;
  final lower = text.toLowerCase();
  if (lower.contains('ł') || (lower.contains('ą') && lower.contains('ę'))) return 'pl-PL';
  if (lower.contains('ß')) return 'de-DE';
  if (lower.contains('ñ')) return 'es-ES';
  if (lower.contains('ã') || lower.contains('õ')) return 'pt-BR';
  if (lower.contains('ř')) return 'cs-CZ';
  if (lower.contains('ğ') || lower.contains('ı')) return 'tr-TR';
  if (lower.contains('ő') || lower.contains('ű')) return 'hu-HU';
  if (RegExp('[ơưạếệộ]').hasMatch(lower)) return 'vi-VN';
  return null;
}
