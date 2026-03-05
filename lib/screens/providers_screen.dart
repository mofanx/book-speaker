import 'package:flutter/material.dart';
import '../models/ai_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/service_locator.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  List<AiProvider> _providers = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _providers = settingsService.getProviders());
  }

  Future<void> _deleteProvider(AiProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('delete_provider')),
        content: Text(t('delete_provider_confirm').replaceAll('%s', p.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('delete'),
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await settingsService.deleteProvider(p.id);
      _reload();
    }
  }

  Future<void> _openEditor([AiProvider? existing]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ProviderEditorScreen(provider: existing),
      ),
    );
    if (result == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('providers_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: t('add_provider'),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _providers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(t('no_providers'),
                      style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text(t('no_providers_hint'),
                      style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _providers.length,
              itemBuilder: (_, i) {
                final p = _providers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(p.type.label[0],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(p.type.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _openEditor(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          onPressed: () => _deleteProvider(p),
                        ),
                      ],
                    ),
                    onTap: () => _openEditor(p),
                  ),
                );
              },
            ),
    );
  }
}

// ====== Provider Editor ======

class _ProviderEditorScreen extends StatefulWidget {
  final AiProvider? provider;
  const _ProviderEditorScreen({this.provider});

  @override
  State<_ProviderEditorScreen> createState() => _ProviderEditorScreenState();
}

class _ProviderEditorScreenState extends State<_ProviderEditorScreen> {
  late ProviderType _type;
  late TextEditingController _nameCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _type = p?.type ?? ProviderType.openai;
    _nameCtrl = TextEditingController(text: p?.name ?? _type.label);
    _keyCtrl = TextEditingController(text: p?.apiKey ?? '');
    _urlCtrl = TextEditingController(text: p?.baseUrl ?? _type.defaultBaseUrl);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_name_required'))));
      return;
    }
    if (_keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_key_required'))));
      return;
    }

    final provider = AiProvider(
      id: widget.provider?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      type: _type,
      apiKey: _keyCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim(),
    );
    await settingsService.saveProvider(provider);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _test() async {
    if (_keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_key_required'))));
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final tmpProvider = AiProvider(
      id: 'test',
      name: 'test',
      type: _type,
      apiKey: _keyCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim(),
    );

    // Pick a lightweight model for the test
    String testModel;
    switch (_type) {
      case ProviderType.openai:
        testModel = 'gpt-4o-mini';
        break;
      case ProviderType.google:
        testModel = 'gemini-2.0-flash';
        break;
      case ProviderType.azure:
        testModel = 'gpt-4o-mini';
        break;
      case ProviderType.custom:
        testModel = 'gpt-4o-mini';
        break;
    }

    final err = await llmService.testProvider(tmpProvider, testModel);
    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = err == null
            ? t('provider_test_success')
            : t('provider_test_failed').replaceAll('%s', err);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.provider != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? t('edit_provider') : t('add_provider')),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider type
          Text(t('provider_type'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<ProviderType>(
            segments: ProviderType.values
                .map((e) =>
                    ButtonSegment(value: e, label: Text(e.label)))
                .toList(),
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() {
                _type = s.first;
                if (_nameCtrl.text.isEmpty ||
                    ProviderType.values
                        .any((e) => _nameCtrl.text == e.label)) {
                  _nameCtrl.text = _type.label;
                }
                _urlCtrl.text = _type.defaultBaseUrl;
              });
            },
          ),
          const SizedBox(height: 20),

          // Name
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: t('provider_name'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // API Key
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: t('provider_api_key'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Base URL
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: t('provider_base_url'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Test button
          FilledButton.icon(
            onPressed: _isTesting ? null : _test,
            icon: _isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.wifi_tethering),
            label: Text(_isTesting ? t('testing') : t('test')),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testResult == t('provider_test_success')
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult == t('provider_test_success')
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
