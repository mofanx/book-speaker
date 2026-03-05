import 'dart:io';
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
  String? _ttsTestResult;

  late TtsService _tts;

  @override
  void initState() {
    super.initState();
    final s = settingsService;
    _ttsVoiceCtrl = TextEditingController(text: s.ttsVoice);
    _ttsModelCtrl = TextEditingController(text: s.ttsModel);
    _ocrModelCtrl = TextEditingController(text: s.ocrModel);
    _textOptModelCtrl = TextEditingController(text: s.textOptModel);
    _tts = TtsService.instance(settingsService);
    _tts.init();
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
    final cs = Theme.of(context).colorScheme;

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

          // System TTS: iOS-style card with config + test
          if (s.ttsMode == TtsMode.system) ...[
            const SizedBox(height: 4),
            _buildSystemTtsCard(cs),
          ],

          // Cloud / LLM TTS: show provider/model/voice
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

          // Test TTS button + result
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
          if (_ttsTestResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _ttsTestResult == t('success')
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ttsTestResult!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _ttsTestResult == t('success')
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
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
            subtitle: Text('v1.3.0 — ${t('app_name')}'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---- System TTS Card (Kelivo-style) ----

  Widget _buildSystemTtsCard(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final available = _tts.isInitialized && _tts.error == null;
    final statusText = available
        ? t('tts_system_available')
        : (_tts.error ?? t('tts_no_engine'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
            width: 0.6,
          ),
        ),
        child: Column(
          children: [
            // System TTS row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : cs.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.record_voice_over,
                        size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('tts_system'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: cs.onSurface.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 3),
                        Text(statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: available
                                  ? Colors.green.shade600
                                  : Colors.orange.shade600,
                            )),
                      ],
                    ),
                  ),
                  // Test speak button
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 20),
                    tooltip: t('tts_test'),
                    onPressed: available
                        ? () async {
                            await _tts.testSystemSpeak('Hello, this is a test.');
                          }
                        : null,
                  ),
                  // Config button
                  IconButton(
                    icon: const Icon(Icons.tune, size: 20),
                    tooltip: t('tts_system_config'),
                    onPressed: available
                        ? () => _showSystemTtsConfigSheet(context)
                        : null,
                  ),
                ],
              ),
            ),
            // Open system settings
            if (Platform.isAndroid) ...[
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 54,
                endIndent: 12,
                color: cs.outlineVariant.withOpacity(0.18),
              ),
              InkWell(
                onTap: () async {
                  await TtsService.openSystemTtsSettings();
                },
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Icon(Icons.settings,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('tts_open_system_settings'),
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 18,
                          color: cs.onSurface.withOpacity(0.4)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---- System TTS Config Bottom Sheet ----

  void _showSystemTtsConfigSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    double rate = _tts.rate;
    double pitch = _tts.pitch;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(t('tts_system_config'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                // Engine selector
                FutureBuilder<List<String>>(
                  future: _tts.getEngines(),
                  builder: (context, snap) {
                    final engines = snap.data ?? const <String>[];
                    final cur = _tts.engineId.isNotEmpty
                        ? _tts.engineId
                        : (engines.isNotEmpty ? engines.first : '');
                    return _sheetSelectRow(
                      context,
                      label: t('tts_engine'),
                      value: cur.isEmpty ? t('tts_engine_default') : _engineDisplayName(cur),
                      options: engines,
                      displayName: _engineDisplayName,
                      onSelected: (picked) async {
                        await _tts.setEngineId(picked);
                        (ctx as Element).markNeedsBuild();
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
                const SizedBox(height: 4),
                // Language selector
                FutureBuilder<List<String>>(
                  future: _tts.getLanguages(),
                  builder: (context, snap) {
                    final langs = snap.data ?? const <String>[];
                    final cur = _tts.languageTag.isNotEmpty
                        ? _tts.languageTag
                        : (langs.contains('zh-CN')
                            ? 'zh-CN'
                            : (langs.contains('en-US')
                                ? 'en-US'
                                : (langs.isNotEmpty ? langs.first : '')));
                    return _sheetSelectRow(
                      context,
                      label: t('tts_language'),
                      value: cur.isEmpty ? t('tts_engine_default') : cur,
                      options: langs,
                      onSelected: (picked) async {
                        await _tts.setLanguageTag(picked);
                        (ctx as Element).markNeedsBuild();
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Speech rate slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(t('tts_speech_rate'),
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.7))),
                ),
                StatefulBuilder(
                  builder: (ctx2, setSlider) {
                    return Slider(
                      value: rate,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(rate * 2).toStringAsFixed(1)}x',
                      onChanged: (v) {
                        setSlider(() => rate = v);
                      },
                      onChangeEnd: (v) async {
                        await _tts.setRate(v);
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
                const SizedBox(height: 4),
                // Pitch slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(t('tts_pitch'),
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.7))),
                ),
                StatefulBuilder(
                  builder: (ctx2, setSlider) {
                    return Slider(
                      value: pitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: pitch.toStringAsFixed(1),
                      onChanged: (v) {
                        setSlider(() => pitch = v);
                      },
                      onChangeEnd: (v) async {
                        await _tts.setPitch(v);
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(ctx).maybePop(),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(t('done')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Sheet select row (Kelivo-style) ----

  Widget _sheetSelectRow(
    BuildContext context, {
    required String label,
    required String value,
    required List<String> options,
    String Function(String)? displayName,
    required Future<void> Function(String picked) onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: options.isEmpty
          ? null
          : () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: cs.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx2) {
                  return SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx2).size.height * 0.6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 0.6,
                                indent: 16,
                                endIndent: 16,
                                color: cs.outlineVariant.withOpacity(0.18),
                              ),
                              itemBuilder: (_, i) {
                                final display = displayName != null
                                    ? displayName(options[i])
                                    : options[i];
                                return ListTile(
                                  title: Text(display,
                                      style: const TextStyle(fontSize: 15)),
                                  trailing: options[i] == value
                                      ? Icon(Icons.check,
                                          size: 18, color: cs.primary)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(ctx2).pop(options[i]),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
              if (picked != null && picked.isNotEmpty) {
                await onSelected(picked);
              }
            },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurface.withOpacity(0.9))),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                displayName != null ? displayName(value) : value,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.6)),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: cs.onSurface.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  static String _engineDisplayName(String engine) {
    if (engine.contains('google')) return 'Google TTS';
    if (engine.contains('xiaomi') || engine.contains('mibrain')) return 'Xiaomi TTS';
    if (engine.contains('iflytek')) return 'iFlytek TTS';
    if (engine.contains('samsung')) return 'Samsung TTS';
    return engine;
  }

  // ---- TTS test ----

  Future<void> _testTts() async {
    setState(() {
      _ttsTesting = true;
      _ttsTestResult = null;
    });

    await _tts.init();
    final err = await _tts.testSpeak();

    if (mounted) {
      setState(() {
        _ttsTesting = false;
        _ttsTestResult = err == null ? t('success') : err;
      });
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
