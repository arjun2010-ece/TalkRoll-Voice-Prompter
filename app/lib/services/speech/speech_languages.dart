/// The languages Voice and Audio mode can be asked to recognise, and how the one to use is chosen.
///
/// The list is the reference app's (`kw2`); the detector is a port of its `rg3.e0` / `rg3.g0`: it reads the first
/// 2000 characters of the script, counts letters per writing system and, for Latin text, looks for letters only
/// some languages use. A script it can't place is English, as in the reference.
library;

import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'native_speech_recognizer.dart';

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

/// English first, then the rest by name, as the reference lists them. Thai is listed on Apple only.
final List<SpeechLanguage> speechLanguages = (() {
  final all = [
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
    // Apple only: a Thai script is followed letter by letter (ScriptTracker), which Android's recogniser path doesn't use.
    if (Platform.isMacOS || Platform.isIOS) SpeechLanguage('th-TH', 'Thai'),
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
/// from different sources. Android names Mandarin `cmn` (`cmn-Hans-CN`) and still uses some old codes (`iw`, `in`);
/// they are read as the list's `zh`, `he` and `id` (Apple never uses them, so nothing changes there).
String _key(String tag) {
  final parts = tag.replaceAll('_', '-').toLowerCase().split('-');
  parts[0] = const {'cmn': 'zh', 'iw': 'he', 'in': 'id'}[parts[0]] ?? parts[0];
  return parts.length == 3 && parts[1].length == 4 ? '${parts[0]}-${parts[2]}' : parts.join('-');
}

/// Whether [tag] is among the languages the device reports it can recognise ([supported]); true when it reports none.
bool speechLanguageListed(String tag, Iterable<String> supported) =>
    supported.isEmpty || supported.any((s) => _key(s) == _key(tag));

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
  bool android = false,
}) {
  if (setting != autoSpeechLanguage) return setting;
  // Android reads the script with its own text classifier ([detected]); Apple's path below is unchanged.
  if (android) return _androidLanguage(script, detected, deviceTag, supported);
  final found = detected != null ? languageFromNaturalLanguage(detected) : detectScriptLanguage(script);
  if (found == null) return defaultSpeechLanguage;
  if (detected != null && supported.isNotEmpty) return _deviceVariantOf(found, deviceTag, supported);
  return _variantOf(found, deviceTag, supported);
}

/// The language Voice and Narration mode listen for with [script]: the setting, or (Automatic) the script's own
/// language as this device reads it. The one place that decides it, so what "How to read" shows is what is used.
Future<String> speechLanguageForScript({
  required NativeSpeechRecognizer? native,
  required String setting,
  required String script,
}) async {
  final auto = setting == autoSpeechLanguage;
  return resolveSpeechLanguage(
    setting: setting,
    script: script,
    deviceTag: PlatformDispatcher.instance.locale.toLanguageTag(),
    detected: auto && native != null ? await native.detectLanguage(script) : null,
    supported: auto && native != null ? await native.supportedLanguages() : const [],
    android: Platform.isAndroid,
  );
}

/// Android: the language of [script] from the text classifier's reading ([classified]), else common words or the
/// writing system; null when nothing can tell.
String? androidScriptLanguage(String script, String? classified) =>
    (classified != null ? languageFromTextClassifier(classified, script) : null) ?? _androidFallback(script);

/// Android: the text classifier's reading of the script, else common words (Latin text) or the writing system.
String _androidLanguage(String script, String? classified, String deviceTag, Iterable<String> supported) {
  final found = (classified != null ? languageFromTextClassifier(classified, script) : null) ?? _androidFallback(script);
  if (found == null) return defaultSpeechLanguage;
  // These variants are decided by the text itself, not the phone's region: Simplified or Traditional characters,
  // and Hindi typed in English letters (an English (India) recogniser writes Latin letters, as the script does).
  if (const {'zh-CN', 'zh-TW', 'en-IN'}.contains(found) && (supported.isEmpty || supported.any((s) => sameSpeechTag(s, found)))) {
    return found;
  }
  // Android lists only the languages it can recognise offline; the others may still work through the system
  // recogniser (online, or after a download). A detected language is kept rather than swapped for English, and
  // "How to read" shows it before Start.
  final listed = _variantOf(found, deviceTag, supported);
  if (sameSpeechLanguage(listed, found)) return listed;
  return _variantOf(found, deviceTag, const []);
}

/// Android's text classifier tag (`pt`, `bs`, `hi-Latn`, `zh`, legacy `iw`/`in`) as a list tag; null when it isn't
/// one of [speechLanguages].
String? languageFromTextClassifier(String code, String script) {
  final c = code.replaceAll('_', '-').toLowerCase();
  if (c.startsWith('hi-latn')) return 'en-IN';
  final language = c.split('-').first;
  if (language == 'zh' || language == 'yue') return _traditionalChinese(script) ? 'zh-TW' : 'zh-CN';
  // Croatian is often read as Bosnian; the others are Android's older codes.
  final mapped = const {'bs': 'hr', 'iw': 'he', 'in': 'id', 'no': 'nb', 'nn': 'nb'}[language] ?? language;
  return _listTagFor(mapped);
}

/// The list tag for a bare language code (`pt` -> `pt-BR`), or null when the language isn't listed.
String? _listTagFor(String code) {
  final main = const {'es': 'es-ES', 'fr': 'fr-FR', 'pt': 'pt-BR'}[code];
  if (main != null) return main;
  for (final l in speechLanguages) {
    if (l.code == code) return l.tag;
  }
  return null;
}

/// Characters written differently in Traditional and Simplified Chinese; whichever set the script uses more.
bool _traditionalChinese(String script) {
  const traditional = '們這個來說時會對為發與經點裡後過還開關問應實現體機總從當讓變處區專業權門車書長東聽買賣頭種萬並們請預設鐘話題';
  const simplified = '们这个来说时会对为发与经点里后过还开关问应实现体机总从当让变处区专业权门车书长东听买卖头种万并们请预设钟话题';
  var t = 0, s = 0;
  for (final r in script.runes) {
    final ch = String.fromCharCode(r);
    if (traditional.contains(ch)) t++;
    if (simplified.contains(ch)) s++;
  }
  return t > s;
}

/// Android without a usable classifier reading (below Android 10, or it couldn't tell): common words for text in
/// Latin letters, else the writing system and letters only some languages use ([detectScriptLanguage]).
String? _androidFallback(String script) {
  final text = script.length > 2000 ? script.substring(0, 2000) : script;
  final latin = RegExp('[A-Za-z]').allMatches(text).length;
  final letters = RegExp(r'\p{L}', unicode: true).allMatches(text).length;
  if (letters > 0 && latin * 2 > letters) {
    final byWords = commonWordsLanguage(text);
    if (byWords != null) return byWords;
  }
  return detectScriptLanguage(script);
}

/// The most common short words of the Latin-script languages in [speechLanguages], for telling them apart when no
/// classifier can. Matched without accents, so text typed without them still counts.
const _commonWords = <String, String>{
  'en': 'the and to of a in is it you that for on with as are this be at have from or not by we will can your all what so if there do one',
  'pt': 'o os as de do da dos das e é em no na nos um uma que para com por não se mais seu sua você ao como mas foi está são isso também muito vai até depois',
  'es': 'el la los las de del y es en un una que para con por no se más su sus lo al como pero está son esto también muy va hasta hay después',
  'fr': 'le la les de des du et est en un une que pour avec par pas ne se plus son sa vous nous il elle au aux dans sur ce qui mais',
  'it': 'il lo la i gli le di del della e è in un una che per con non si più suo sua al come ma sono questo anche molto nel alla poi',
  'de': 'der die das und ist in ein eine zu den dem nicht mit von sich auf für es sie ich wir ihr auch als an werden noch nach bei',
  'nl': 'de het een en is in van op te dat niet met voor zijn je we er die aan ook als bij of maar naar dan om wat',
  'ca': 'el la els les de del i és en un una que per amb no es més seu seva al com però està són això també molt',
  'ro': 'și în de la cu pe un o este nu ce sunt mai care pentru din se a fi ca dar sau acest această',
  'pl': 'i w na z do się nie to jest że o jak ale co po za od dla przez czy tak już są oraz',
  'cs': 'a v na se je že s z do to o jak ale co po za od pro jsou by být tak už jen který',
  'sk': 'a v na sa je že s z do to o ako ale čo po za od pre sú by byť tak už len ktorý',
  'sl': 'in v na se je da s z do to o kot ali kaj po za od pri so bi biti tako že samo ki',
  'hr': 'i u na se je da s sa do to o kao ali što po za od pri su bi biti tako već samo koji',
  'hu': 'a az és egy hogy nem is meg ez el van de csak mint ki be fel már még vagy',
  'fi': 'ja on ei se että hän ovat oli mutta kun niin myös tai jos mitä nyt sitten vain kuin',
  'sv': 'och i att det som en på är av för med till den har inte om ett de jag men så var också',
  'da': 'og i at det som en på er af for med til den har ikke om et de jeg men så var også hvad nogen meget efter nu jer',
  'nb': 'og i at det som en på er av for med til den har ikke om et de jeg men så var også hva noen mye etter nå dere',
  'id': 'yang dan di ke dari ini itu untuk dengan tidak akan ada adalah juga dalam saya anda kita bisa sudah atau pada lalu setelah baru karena',
  'ms': 'yang dan di ke dari ini itu untuk dengan tidak akan ada adalah juga dalam saya anda kita boleh sudah atau pada kemudian selepas baharu kerana',
  'tr': 've bir bu da de için ile çok daha gibi ne o en mi sonra kadar var olan ama',
  'vi': 'và là của có không được cho một những các trong này đã với người để khi thì sẽ',
};

/// [s] lowercased with accents removed, so `não` and `nao` match.
String _foldAccents(String s) {
  const from = 'àáâãäåăąèéêëěęìíîïòóôõöőùúûüůűçčćșşšțťţžźżñňńřłďľýğı';
  const to = 'aaaaaaaaeeeeeeiiiioooooouuuuuucccssstttzzznnnrldlygi';
  final out = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}

final _commonWordSets = {
  for (final e in _commonWords.entries) e.key: e.value.split(' ').map(_foldAccents).toSet(),
};

/// The Latin-script language whose common words appear most in [text], or null under three of them.
String? commonWordsLanguage(String text) {
  final words = [for (final m in RegExp(r"[\p{L}']+", unicode: true).allMatches(text)) _foldAccents(m[0]!)];
  String? best;
  var bestCount = 0;
  for (final e in _commonWordSets.entries) {
    final n = words.where(e.value.contains).length;
    if (n > bestCount) {
      best = e.key;
      bestCount = n;
    }
  }
  return best != null && bestCount >= 3 ? _listTagFor(best) : null;
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
