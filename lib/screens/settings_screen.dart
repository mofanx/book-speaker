import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/settings.dart';
import '../models/ai_provider.dart';
import '../services/service_locator.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';
import '../l10n/app_localizations.dart';
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
  late TextEditingController _translationModelCtrl;
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
    _translationModelCtrl = TextEditingController(text: s.translationModel);
    _tts = TtsService.instance(settingsService);
    _tts.init();
  }

  @override
  void dispose() {
    _ttsVoiceCtrl.dispose();
    _ttsModelCtrl.dispose();
    _ocrModelCtrl.dispose();
    _textOptModelCtrl.dispose();
    _translationModelCtrl.dispose();
    super.dispose();
  }

  List<AiProvider> get _providers => settingsService.getProviders();

  // ---- Backup & Restore ----

  Future<void> _exportBackup() async {
    final result = await backupService.exportData();
    if (!mounted) return;
    
    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('export_success'))),
      );
    } else if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('operation_failed').replaceAll('%s', result))),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('import_confirm_title')),
        content: Text(t('import_confirm_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('confirm')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await backupService.importData();
    if (!mounted) return;

    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('import_success'))),
      );
      // Data changed significantly, trigger a full reload
      setState(() {});
    } else if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('operation_failed').replaceAll('%s', result))),
      );
    }
  }

  // ---- Update Check ----

  Future<void> _checkForUpdate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(t('checking_update')),
          ],
        ),
      ),
    );

    final info = await updateService.checkForUpdate();
    if (!mounted) return;
    
    Navigator.pop(context); // close loading dialog

    if (info != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('update_available').replaceAll('%s', info.latestVersion)),
          content: SingleChildScrollView(
            child: Text(info.releaseNotes),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                updateService.launchDownloadUrl(info.downloadUrl);
              },
              child: Text(t('update_now')),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('already_latest'))),
      );
    }
  }

  // ---- Builders ----

  @override
  Widget build(BuildContext context) {
    final s = settingsService;
    final providers = _providers;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        children: [
          // =========== App Settings ===========
          _section(t('settings')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('theme_mode'),
                    style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withOpacity(0.7))),
                const SizedBox(height: 8),
                SegmentedButton<AppThemeMode>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: AppThemeMode.system,
                      icon: const Icon(Icons.brightness_auto, size: 16),
                      label: Text(t('theme_system')),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      icon: const Icon(Icons.light_mode, size: 16),
                      label: Text(t('theme_light')),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      icon: const Icon(Icons.dark_mode, size: 16),
                      label: Text(t('theme_dark')),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (Set<AppThemeMode> newSelection) {
                    setState(() {
                      s.themeMode = newSelection.first;
                      S.setLocale(s.appLocale);
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(),
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

          // System TTS: simplified - only show status + open system settings
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
              _modelSelector(
                label: t('tts_model'),
                selectedId: s.ttsModel,
                providerId: s.ttsProviderId,
                providers: providers,
                onChanged: (v) => setState(() => s.ttsModel = v),
                hint: t('tts_model_hint'),
                controller: _ttsModelCtrl,
              ),
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
            _modelSelector(
              label: t('ocr_model'),
              selectedId: s.ocrModel,
              providerId: s.ocrProviderId,
              providers: providers,
              onChanged: (v) => setState(() => s.ocrModel = v),
              hint: t('ocr_model_hint'),
              controller: _ocrModelCtrl,
            ),
          ],
          _buildPromptEditor(
            label: t('ocr_custom_prompt'),
            currentValue: settingsService.ocrPrompt,
            defaultPrompt: SettingsService.defaultOcrPrompt,
            onSave: (v) {
              setState(() {
                settingsService.ocrPrompt = v;
              });
            },
          ),
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
            _modelSelector(
              label: t('text_opt_model'),
              selectedId: s.textOptModel,
              providerId: s.textOptProviderId,
              providers: providers,
              onChanged: (v) => setState(() => s.textOptModel = v),
              hint: t('text_opt_model_hint'),
              controller: _textOptModelCtrl,
            ),
          ],
          _buildPromptEditor(
            label: t('text_opt_custom_prompt'),
            currentValue: settingsService.textOptPrompt,
            defaultPrompt: SettingsService.defaultTextOptPrompt,
            onSave: (v) {
              setState(() {
                settingsService.textOptPrompt = v;
              });
            },
          ),
          const Divider(),

          // =========== Translation ===========
          _section(t('settings_translation')),
          _providerSelector(
            label: t('translation_provider'),
            selectedId: s.translationProviderId,
            providers: providers,
            onChanged: (id) => setState(() => s.translationProviderId = id),
          ),
          if (s.translationProviderId.isNotEmpty)
            _modelSelector(
              label: t('translation_model'),
              selectedId: s.translationModel,
              providerId: s.translationProviderId,
              providers: providers,
              onChanged: (v) => setState(() => s.translationModel = v),
              hint: t('translation_model_hint'),
              controller: _translationModelCtrl,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: s.translationTargetLang,
              decoration: InputDecoration(
                labelText: t('translation_target_lang'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: 'zh', child: Text(t('translation_target_zh'))),
                DropdownMenuItem(value: 'en', child: Text(t('translation_target_en'))),
              ],
              onChanged: (v) => setState(() => s.translationTargetLang = v ?? 'zh'),
            ),
          ),
          const Divider(),

          // =========== Data Management ===========
          _section(t('data_management')),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(t('export_backup')),
            onTap: _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(t('import_backup')),
            onTap: _importBackup,
          ),
          const Divider(),

          // =========== About ===========
          _section(t('about')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Book Speaker'),
            subtitle: Text('v1.3.0 — ${t('app_name')}'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(t('check_update')),
            onTap: _checkForUpdate,
          ),
          ListTile(
            leading: const Icon(Icons.code, color: Colors.black87),
            title: Text(t('about_github')),
            subtitle: const Text(
              'https://github.com/mofanx/book-speaker',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              const url = 'https://github.com/mofanx/book-speaker';
              if (Platform.isAndroid) {
                final intent = AndroidIntent(
                  action: 'android.intent.action.VIEW',
                  data: url,
                );
                await intent.launch();
              } else {
                await Clipboard.setData(ClipboardData(text: url));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('copied'))));
                }
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---- System TTS Card (simplified) ----

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
                ],
              ),
            ),
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

  Widget _modelSelector({
    required String label,
    required String selectedId,
    required String providerId,
    required List<AiProvider> providers,
    required ValueChanged<String> onChanged,
    required String hint,
    required TextEditingController controller,
  }) {
    // Keep controller text in sync
    if (controller.text != selectedId) {
      controller.text = selectedId;
    }

    final provider = providers.where((p) => p.id == providerId).firstOrNull;

    // If provider not found or has no favorited models, fallback to text field
    if (provider == null || provider.favoriteModels.isEmpty) {
      return _field(label, controller, onChanged, hint);
    }

    // Ensure selectedId is in the list or add it temporarily for the dropdown
    final models = provider.favoriteModels.toList();
    if (selectedId.isNotEmpty && !models.contains(selectedId)) {
      models.insert(0, selectedId);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: selectedId.isNotEmpty && models.contains(selectedId)
            ? selectedId
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: models
            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
            .toList(),
        onChanged: (v) {
          controller.text = v ?? '';
          onChanged(v ?? '');
        },
      ),
    );
  }

  Widget _buildPromptEditor({
    required String label,
    required String currentValue,
    required String defaultPrompt,
    required ValueChanged<String> onSave,
  }) {
    final displayValue = currentValue.isNotEmpty ? currentValue : defaultPrompt;
    final isDefault = currentValue.isEmpty;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: cs.onSurface.withOpacity(0.7))),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              _showPromptDialog(
                label: label,
                initialValue: currentValue,
                defaultPrompt: defaultPrompt,
                onSave: onSave,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(12),
                color: cs.surfaceContainerHighest.withOpacity(0.3),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayValue,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDefault 
                            ? cs.onSurface.withOpacity(0.5) 
                            : cs.onSurface,
                        fontStyle: isDefault ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit_note, size: 20, color: cs.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPromptDialog({
    required String label,
    required String initialValue,
    required String defaultPrompt,
    required ValueChanged<String> onSave,
  }) {
    final ctrl = TextEditingController(text: initialValue);
    final cs = Theme.of(context).colorScheme;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PromptDialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 20,
                right: 20,
              ),
              child: GestureDetector(
                onTap: () {}, // consume tap to prevent dismissing when clicking inside card
                child: Hero(
                  tag: 'prompt_editor_$label',
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    elevation: 8,
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.75,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune, color: cs.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: defaultPrompt,
                                hintStyle: TextStyle(
                                  color: cs.onSurface.withOpacity(0.4),
                                  fontStyle: FontStyle.italic,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest.withOpacity(0.2),
                              ),
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  ctrl.clear();
                                  onSave('');
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(t('reset_to_default')),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.error,
                                ),
                              ),
                              FilledButton(
                                onPressed: () {
                                  onSave(ctrl.text.trim());
                                  Navigator.of(context).pop();
                                },
                                child: Text(t('save')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
