import 'package:i18n_extension_core/i18n_extension_core.dart';

extension Localization on String {
  static final _t = Translations.byText('en-US') +
      {
        "en-US": "Reason:", // English
        "es": "Razón:", // Spanish
        "fr": "Raison:", // French
        "de": "Grund:", // German
        "zh": "原因:", // Chinese
        "jp": "理由:", // Japanese
        "pt": "Motivo:", // Portuguese
        "it": "Motivo:", // Italian
        "pl": "Powód:", // Polish
        "ko": "이유:", // Korean
        "ms": "Sebab:", // Malay
        "ru": "Причина:", // Russian
        "uk": "Причина:", // Ukrainian
        "ar": "السبب", // Arabic
        "he": "סיבה", // Hebrew
      };

  String get i18n => localize(this, _t);
}
