import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/service_locator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ttsApiKeyCtrl;
  late TextEditingController _ttsRegionCtrl;
  late TextEditingController _ttsVoiceCtrl;
  late TextEditingController _llmApiKeyCtrl;
  late TextEditingController _llmEndpointCtrl;
  late TextEditingController _llmModelCtrl;

  @override
  void initState() {
    super.initState();
    final s = settingsService;
    _ttsApiKeyCtrl = TextEditingController(text: s.ttsApiKey);
    _ttsRegionCtrl = TextEditingController(text: s.ttsRegion);
    _ttsVoiceCtrl = TextEditingController(text: s.ttsVoice);
    _llmApiKeyCtrl = TextEditingController(text: s.llmApiKey);
    _llmEndpointCtrl = TextEditingController(text: s.llmEndpoint);
    _llmModelCtrl = TextEditingController(text: s.llmModel);
  }

  @override
  void dispose() {
    _ttsApiKeyCtrl.dispose();
    _ttsRegionCtrl.dispose();
    _ttsVoiceCtrl.dispose();
    _llmApiKeyCtrl.dispose();
    _llmEndpointCtrl.dispose();
    _llmModelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = settingsService;
    final needsLlm = s.enableTextOptimization || s.ocrEngine == OcrEngine.llm;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ---- TTS Section ----
          _sectionHeader('TTS (Text-to-Speech)'),
          _buildDropdown<TtsEngine>(
            title: 'Engine',
            value: s.ttsEngine,
            items: TtsEngine.values,
            labelOf: (e) => e.label,
            onChanged: (v) => setState(() => s.ttsEngine = v),
          ),
          if (s.ttsEngine != TtsEngine.system) ...[
            _buildTextField(
              label: 'API Key',
              controller: _ttsApiKeyCtrl,
              onChanged: (v) => s.ttsApiKey = v,
              obscure: true,
            ),
            if (s.ttsEngine == TtsEngine.azure)
              _buildTextField(
                label: 'Region',
                controller: _ttsRegionCtrl,
                onChanged: (v) => s.ttsRegion = v,
                hint: 'e.g. eastus',
              ),
            _buildTextField(
              label: 'Voice',
              controller: _ttsVoiceCtrl,
              onChanged: (v) => s.ttsVoice = v,
              hint: s.ttsEngine == TtsEngine.azure
                  ? 'e.g. en-US-JennyNeural'
                  : 'e.g. en-US-Neural2-C',
            ),
          ],
          const Divider(),

          // ---- OCR Section ----
          _sectionHeader('OCR (Image Recognition)'),
          _buildDropdown<OcrEngine>(
            title: 'Engine',
            value: s.ocrEngine,
            items: OcrEngine.values,
            labelOf: (e) => e.label,
            onChanged: (v) => setState(() => s.ocrEngine = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              s.ocrEngine.description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const Divider(),

          // ---- LLM Section ----
          _sectionHeader('LLM (AI Text Processing)'),
          SwitchListTile(
            title: const Text('Text Optimization'),
            subtitle: const Text('Use AI to clean up pasted text'),
            value: s.enableTextOptimization,
            onChanged: (v) => setState(() => s.enableTextOptimization = v),
          ),
          if (needsLlm) ...[
            _buildDropdown<LlmProvider>(
              title: 'LLM Provider',
              value: s.llmProvider,
              items: LlmProvider.values,
              labelOf: (e) => e.label,
              onChanged: (v) {
                setState(() {
                  s.llmProvider = v;
                  _llmModelCtrl.text = v.defaultModel;
                  s.llmModel = v.defaultModel;
                });
              },
            ),
            _buildTextField(
              label: 'API Key',
              controller: _llmApiKeyCtrl,
              onChanged: (v) => s.llmApiKey = v,
              obscure: true,
            ),
            if (s.llmProvider.needsEndpoint)
              _buildTextField(
                label: 'Endpoint',
                controller: _llmEndpointCtrl,
                onChanged: (v) => s.llmEndpoint = v,
                hint: 'https://your-resource.openai.azure.com',
              ),
            _buildTextField(
              label: 'Model',
              controller: _llmModelCtrl,
              onChanged: (v) => s.llmModel = v,
              hint: s.llmProvider.defaultModel,
            ),
          ],
          const Divider(),

          // ---- About ----
          _sectionHeader('About'),
          const ListTile(
            title: Text('Book Speaker'),
            subtitle: Text('v1.0.0 — English reading assistant for children'),
            leading: Icon(Icons.info_outline),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---- Helper Widgets ----

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String title,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    bool obscure = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: obscure,
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
