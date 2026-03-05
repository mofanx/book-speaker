import 'settings_service.dart';
import 'storage_service.dart';
import 'llm_service.dart';

final settingsService = SettingsService();
final storageService = StorageService();
late final LlmService llmService;

Future<void> initServices() async {
  await settingsService.init();
  await storageService.init();
  llmService = LlmService(settingsService);
}
