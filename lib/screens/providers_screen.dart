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
  late TextEditingController _testModelCtrl;
  bool _isTesting = false;
  bool _isFetchingModels = false;
  String? _testResult;
  List<String> _models = [];
  Set<String> _favoriteModels = {};
  String _testModel = '';

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _type = p?.type ?? ProviderType.openai;
    _nameCtrl = TextEditingController(text: p?.name ?? _type.label);
    _keyCtrl = TextEditingController(text: p?.apiKey ?? '');
    _urlCtrl = TextEditingController(text: p?.baseUrl ?? _type.defaultBaseUrl);
    _models = p?.models.toList() ?? [];
    _favoriteModels = p?.favoriteModels.toSet() ?? {};
    _testModel = p?.favoriteModels.isNotEmpty == true
        ? p!.favoriteModels.first
        : _defaultTestModel(_type);
    _testModelCtrl = TextEditingController(text: _testModel);
  }

  static String _defaultTestModel(ProviderType type) {
    switch (type) {
      case ProviderType.google:
        return 'gemini-2.0-flash';
      default:
        return 'gpt-4o-mini';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _testModelCtrl.dispose();
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
      models: _models,
      favoriteModels: _favoriteModels.toList(),
    );
    await settingsService.saveProvider(provider);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _fetchModels() async {
    if (_keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_key_required'))));
      return;
    }

    setState(() {
      _isFetchingModels = true;
    });

    final tmpProvider = AiProvider(
      id: 'test',
      name: 'test',
      type: _type,
      apiKey: _keyCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim(),
    );

    final models = await llmService.fetchModels(tmpProvider);
    
    if (mounted) {
      setState(() {
        _isFetchingModels = false;
        if (models.isNotEmpty) {
          _models = models;
          // Auto-select first favorite as test model if not yet set
          if (_favoriteModels.isEmpty && _testModel.isEmpty) {
            _testModel = models.first;
            _testModelCtrl.text = _testModel;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t("fetch_models")}: ${models.length}'))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('no_models_fetched')))
          );
        }
      });
    }
  }

  Future<void> _test() async {
    if (_keyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_key_required'))));
      return;
    }
    if (_testModel.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('test_model_hint'))));
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

    final err = await llmService.testProvider(tmpProvider, _testModel.trim());
    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = err == null
            ? t('provider_test_success')
            : t('provider_test_failed').replaceAll('%s', err);
      });
    }
  }

  Widget _buildTestModelSelector() {
    final favList = _favoriteModels.toList();
    if (favList.isNotEmpty) {
      // If current test model not in favs, add it temporarily
      final items = favList.toList();
      if (_testModel.isNotEmpty && !items.contains(_testModel)) {
        items.insert(0, _testModel);
      }
      return DropdownButtonFormField<String>(
        value: _testModel.isNotEmpty && items.contains(_testModel) ? _testModel : null,
        decoration: InputDecoration(
          labelText: t('test_model'),
          hintText: t('test_model_hint'),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items
            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
            .toList(),
        onChanged: (v) => setState(() => _testModel = v ?? ''),
      );
    }
    return TextField(
      controller: _testModelCtrl,
      decoration: InputDecoration(
        labelText: t('test_model'),
        hintText: t('test_model_hint'),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => _testModel = v,
    );
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
                // Reset test model to type default if no favorites
                if (_favoriteModels.isEmpty) {
                  _testModel = _defaultTestModel(_type);
                  _testModelCtrl.text = _testModel;
                }
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

          // Models section (Azure uses deployments, no models endpoint)
          if (_type != ProviderType.azure) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('available_models'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _isFetchingModels ? null : _fetchModels,
                  icon: _isFetchingModels
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_download),
                  label: Text(t('fetch_models')),
                ),
              ],
            ),
            if (_models.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(t('no_models_fetched'),
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _models.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    final isFav = _favoriteModels.contains(model);
                    return ListTile(
                      dense: true,
                      title: Text(model, style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? Colors.orange : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isFav) {
                              _favoriteModels.remove(model);
                            } else {
                              _favoriteModels.add(model);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Test model selector
          _buildTestModelSelector(),
          const SizedBox(height: 12),

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
