import 'package:flutter/material.dart';
import '../models/ai_provider.dart';
import '../models/settings.dart';
import '../l10n/app_localizations.dart';
import '../services/service_locator.dart';
import '../services/tts_service.dart';
import 'providers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ttsVoiceCtrl;
  late TextEditingController _ttsModelCtrl;
  late TextEditingController _ocrModelCtrl;
  late TextEditingController _textOptModelCtrl;
  bool _ttsTesting = false;

  @override
  void initState() {
    super.initState();
    final s = settingsService;
    _ttsVoiceCtrl = TextEditingController(text: s.ttsVoice);
    _ttsModelCtrl = TextEditingController(text: s.ttsModel);
    _ocrModelCtrl = TextEditingController(text: s.ocrModel);
    _textOptModelCtrl = TextEditingController(text: s.textOptModel);
  }

  @override
  void dispose() {
    _ttsVoiceCtrl.dispose();
    _ttsModelCtrl.dispose();
    _ocrModelCtrl.dispose();
    _textOptModelCtrl.dispose();
    super.dispose();
  }

  List<AiProvider> get _providers => settingsService.getProviders();

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final s = settingsService;
    final providers = _providers;

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        children: [
          // =========== Language ===========
          _section(t('settings_language')),
          _radioTile<AppLocale>(
            title: 'English',
            value: AppLocale.en,
            groupValue: s.appLocale,
            onChanged: (v) {
              setState(() {
                s.appLocale = v;
                S.setLocale(v);
              });
            },
          ),
          _radioTile<AppLocale>(
            title: '中文',
            value: AppLocale.zh,
            groupValue: s.appLocale,
            onChanged: (v) {
              setState(() {
                s.appLocale = v;
                S.setLocale(v);
              });
            },
          ),
          const Divider(),

          // =========== AI Providers ===========
          _section(t('settings_providers')),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: Text(t('settings_manage_providers')),
            subtitle: Text('${providers.length} ${t('settings_providers').toLowerCase()}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProvidersScreen()));
              setState(() {});
            },
          ),
          const Divider(),

          // =========== TTS ===========
          _section(t('settings_tts')),
          _radioTile<TtsMode>(
            title: t('tts_system'),
            subtitle: t('tts_system_desc'),
            value: TtsMode.system,
            groupValue: s.ttsMode,
            onChanged: (v) => setState(() => s.ttsMode = v),
          ),
          _radioTile<TtsMode>(
            title: t('tts_traditional'),
            subtitle: t('tts_traditional_desc'),
            value: TtsMode.traditional,
            groupValue: s.ttsMode,
            onChanged: (v) => setState(() => s.ttsMode = v),
          ),
          _radioTile<TtsMode>(
            title: t('tts_llm'),
            subtitle: t('tts_llm_desc'),
            value: TtsMode.llm,
            groupValue: s.ttsMode,
            onChanged: (v) => setState(() => s.ttsMode = v),
          ),
          if (s.ttsMode != TtsMode.system) ...[
            _providerSelector(
              label: t('tts_provider'),
              selectedId: s.ttsProviderId,
              providers: providers,
              onChanged: (id) => setState(() => s.ttsProviderId = id),
            ),
            if (s.ttsMode == TtsMode.llm)
              _field(t('tts_model'), _ttsModelCtrl,
                  (v) => s.ttsModel = v, t('tts_model_hint')),
            _field(
                t('tts_voice'),
                _ttsVoiceCtrl,
                (v) => s.ttsVoice = v,
                s.ttsMode == TtsMode.llm
                    ? t('tts_voice_hint_llm')
                    : t('tts_voice_hint_traditional')),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _ttsTesting ? null : _testTts,
              icon: _ttsTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.volume_up, size: 18),
              label: Text(_ttsTesting ? t('testing') : t('tts_test')),
            ),
          ),
          const Divider(),

          // =========== OCR ===========
          _section(t('settings_ocr')),
          _radioTile<OcrMode>(
            title: t('ocr_mlkit'),
            subtitle: t('ocr_mlkit_desc'),
            value: OcrMode.mlkit,
            groupValue: s.ocrMode,
            onChanged: (v) => setState(() => s.ocrMode = v),
          ),
          _radioTile<OcrMode>(
            title: t('ocr_llm'),
            subtitle: t('ocr_llm_desc'),
            value: OcrMode.llm,
            groupValue: s.ocrMode,
            onChanged: (v) => setState(() => s.ocrMode = v),
          ),
          if (s.ocrMode == OcrMode.llm) ...[
            _providerSelector(
              label: t('ocr_provider'),
              selectedId: s.ocrProviderId,
              providers: providers,
              onChanged: (id) => setState(() => s.ocrProviderId = id),
            ),
            _field(t('ocr_model'), _ocrModelCtrl, (v) => s.ocrModel = v,
                t('ocr_model_hint')),
          ],
          const Divider(),

          // =========== Text Optimization ===========
          _section(t('settings_text_opt')),
          SwitchListTile(
            title: Text(t('text_opt_enable')),
            subtitle: Text(t('text_opt_desc')),
            value: s.enableTextOptimization,
            onChanged: (v) => setState(() => s.enableTextOptimization = v),
          ),
          if (s.enableTextOptimization) ...[
            _providerSelector(
              label: t('text_opt_provider'),
              selectedId: s.textOptProviderId,
              providers: providers,
              onChanged: (id) => setState(() => s.textOptProviderId = id),
            ),
            _field(t('text_opt_model'), _textOptModelCtrl,
                (v) => s.textOptModel = v, t('text_opt_model_hint')),
          ],
          const Divider(),

          // =========== About ===========
          _section(t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Book Speaker'),
            subtitle: Text('v1.1.0 — ${t('app_name')}'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---- TTS test ----

  Future<void> _testTts() async {
    setState(() => _ttsTesting = true);
    final tts = TtsService(settingsService);
    await tts.init();
    final err = await tts.testSpeak();
    await Future.delayed(const Duration(seconds: 2));
    await tts.dispose();
    if (mounted) {
      setState(() => _ttsTesting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err == null ? t('success') : '${t('failed')}: $err'),
      ));
    }
  }

  // ---- Reusable widgets ----

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          )),
    );
  }

  Widget _radioTile<T>({
    required String title,
    String? subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T> onChanged,
  }) {
    return RadioListTile<T>(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      dense: true,
    );
  }

  Widget _providerSelector({
    required String label,
    required String selectedId,
    required List<AiProvider> providers,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: (selectedId.isNotEmpty && providers.any((p) => p.id == selectedId))
            ? selectedId
            : '',
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem(value: '', child: Text(t('none'))),
          ...providers.map((p) =>
              DropdownMenuItem(value: p.id, child: Text(p.name))),
        ],
        onChanged: (v) => onChanged(v ?? ''),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      ValueChanged<String> onChanged, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
