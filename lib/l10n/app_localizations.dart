import 'package:flutter/material.dart';
import '../models/settings.dart';

class S {
  static AppLocale _locale = AppLocale.en;
  static final _notifier = ValueNotifier<AppLocale>(AppLocale.en);

  static ValueNotifier<AppLocale> get notifier => _notifier;
  static AppLocale get locale => _locale;

  static void setLocale(AppLocale l) {
    _locale = l;
    _notifier.value = l;
  }

  static String get(String key) => (_strings[_locale]?[key]) ?? key;
}

// --- shorthand ---
String t(String key) => S.get(key);

const _strings = {
  AppLocale.en: _en,
  AppLocale.zh: _zh,
};

const _en = <String, String>{
  // General
  'app_name': 'Book Speaker',
  'settings': 'Settings',
  'save': 'Save',
  'cancel': 'Cancel',
  'delete': 'Delete',
  'edit': 'Edit',
  'add': 'Add',
  'done': 'Done',
  'test': 'Test',
  'testing': 'Testing...',
  'success': 'Success',
  'failed': 'Failed',
  'required': 'Required',
  'select': 'Select',
  'none': 'None',
  'enabled': 'Enabled',
  'disabled': 'Disabled',
  'language': 'Language',
  'version': 'Version',
  'about': 'About',
  'confirm': 'Confirm',
  'name': 'Name',

  // Home
  'no_lessons': 'No lessons yet',
  'tap_add_lesson': 'Tap + to add your first lesson',
  'add_lesson': 'Add Lesson',
  'delete_lesson': 'Delete Lesson',
  'delete_lesson_confirm': 'Delete "%s"?',

  // Import
  'import_lesson': 'Import Lesson',
  'lesson_title': 'Lesson Title',
  'lesson_title_hint': 'e.g. Unit 3 - At the Zoo',
  'take_photo': 'Take Photo',
  'from_gallery': 'From Gallery',
  'paste_text_hint': 'Or paste dialogue text below:',
  'ai_optimize': 'AI Optimize',
  'optimizing': 'Optimizing...',
  'text_optimized': 'Text optimized successfully',
  'optimization_failed': 'Optimization failed',
  'recognizing_text': 'Recognizing text...',
  'ocr_failed': 'OCR failed',
  'enter_title': 'Please enter a title',
  'enter_text': 'Please enter or import some text',
  'no_sentences': 'No sentences found in text',
  'sentences_detected': '%d sentences detected',
  'text_opt_requires_llm': 'Please configure an LLM provider first in Settings',

  // Reader
  'play_all': 'Play All',
  'stop': 'Stop',
  'single_mode': 'Single',
  'continuous_mode': 'Continuous',
  'loop_mode': 'Loop All',
  'play_mode': 'Play mode',
  'select_all': 'Select All',
  'deselect': 'Deselect',
  'delete_selected': 'Delete selected',
  'delete_sentences_title': 'Delete Sentences',
  'delete_sentences_confirm': 'Delete %d sentence(s)?',
  'delete_sentence_title': 'Delete Sentence',
  'delete_sentence_confirm': 'Delete this sentence?',
  'edit_sentence': 'Edit Sentence',
  'add_sentence': 'Add Sentence',
  'speaker_optional': 'Speaker (optional)',
  'text': 'Text',

  // Settings
  'settings_language': 'App Language',
  'settings_tts': 'TTS (Text-to-Speech)',
  'settings_ocr': 'OCR (Image Recognition)',
  'settings_text_opt': 'Text Optimization',
  'settings_providers': 'AI Providers',
  'settings_manage_providers': 'Manage Providers',

  'tts_mode': 'TTS Mode',
  'tts_system': 'System TTS',
  'tts_system_desc': 'Built-in Android TTS (offline)',
  'tts_traditional': 'Cloud TTS API',
  'tts_traditional_desc': 'Azure / Google Cloud TTS',
  'tts_llm': 'LLM TTS',
  'tts_llm_desc': 'OpenAI TTS / compatible API',
  'tts_provider': 'TTS Provider',
  'tts_voice': 'Voice',
  'tts_model': 'Model',
  'tts_model_hint': 'e.g. gpt-4o-mini-tts',
  'tts_voice_hint_traditional': 'e.g. en-US-JennyNeural',
  'tts_voice_hint_llm': 'e.g. alloy, nova, shimmer',
  'tts_test': 'Test TTS',
  'tts_engine': 'TTS Engine',
  'tts_engine_default': 'Default',
  'tts_open_system_settings': 'Open System TTS Settings',
  'tts_open_system_settings_desc': 'Configure TTS engine, download voice data',
  'tts_no_engine': 'No TTS engine found on this device',
  'tts_test_timeout': 'TTS test timed out. Please open system TTS settings to check the engine.',
  'tts_system_available': 'Available',
  'tts_system_config': 'System TTS Settings',
  'tts_speech_rate': 'Speech Rate',
  'tts_pitch': 'Pitch',
  'tts_language': 'Language',

  'ocr_mode': 'OCR Mode',
  'ocr_mlkit': 'ML Kit (Offline)',
  'ocr_mlkit_desc': 'Google ML Kit - works offline',
  'ocr_llm': 'LLM Vision',
  'ocr_llm_desc': 'Use multimodal LLM to extract text',
  'ocr_provider': 'OCR Provider',
  'ocr_model': 'Model',
  'ocr_model_hint': 'e.g. gpt-4o, gemini-2.0-flash',

  'text_opt_enable': 'Enable Text Optimization',
  'text_opt_desc': 'Use AI to clean up pasted dialogue text',
  'text_opt_provider': 'Provider',
  'text_opt_model': 'Model',
  'text_opt_model_hint': 'e.g. gpt-4o-mini',

  // Providers
  'providers_title': 'AI Providers',
  'add_provider': 'Add Provider',
  'edit_provider': 'Edit Provider',
  'delete_provider': 'Delete Provider',
  'delete_provider_confirm': 'Delete provider "%s"?',
  'provider_type': 'Provider Type',
  'provider_name': 'Name',
  'provider_api_key': 'API Key',
  'provider_base_url': 'API Base URL',
  'provider_name_required': 'Name is required',
  'provider_key_required': 'API Key is required',
  'provider_test_success': 'Connection successful!',
  'provider_test_failed': 'Connection failed: %s',
  'no_providers': 'No providers configured',
  'no_providers_hint': 'Tap + to add an AI provider',
  'select_provider': 'Select Provider',
  'no_provider_selected': 'No provider selected',
  'configure_provider_first': 'Please add an AI provider in Settings first',

  // Theme mode
  'theme_mode': 'Theme Mode',
  'theme_system': 'System',
  'theme_light': 'Light',
  'theme_dark': 'Dark',

  // Provider editor extras
  'available_models': 'Available Models',
  'fetch_models': 'Fetch Models',
  'no_models_fetched': 'No models fetched yet',
  'test_model': 'Test Model',
  'test_model_hint': 'Select or enter model for testing',

  // Custom prompts
  'ocr_custom_prompt': 'Custom OCR Prompt',
  'text_opt_custom_prompt': 'Custom Optimization Prompt',
  'reset_to_default': 'Reset to Default',
  'custom_prompt_hint': 'Leave empty to use the default prompt',

  // About
  'about_github': 'GitHub Repository',
  'copied': 'Copied!',
};

const _zh = <String, String>{
  // General
  'app_name': 'Book Speaker',
  'settings': '设置',
  'save': '保存',
  'cancel': '取消',
  'delete': '删除',
  'edit': '编辑',
  'add': '添加',
  'done': '完成',
  'test': '测试',
  'testing': '测试中...',
  'success': '成功',
  'failed': '失败',
  'required': '必填',
  'select': '选择',
  'none': '无',
  'enabled': '已启用',
  'disabled': '已禁用',
  'language': '语言',
  'version': '版本',
  'about': '关于',
  'confirm': '确认',
  'name': '名称',

  // Home
  'no_lessons': '暂无课文',
  'tap_add_lesson': '点击 + 添加第一篇课文',
  'add_lesson': '添加课文',
  'delete_lesson': '删除课文',
  'delete_lesson_confirm': '确定删除 "%s"？',

  // Import
  'import_lesson': '导入课文',
  'lesson_title': '课文标题',
  'lesson_title_hint': '例如：第三单元 - 在动物园',
  'take_photo': '拍照',
  'from_gallery': '从相册',
  'paste_text_hint': '或粘贴对话文本：',
  'ai_optimize': 'AI优化',
  'optimizing': '优化中...',
  'text_optimized': '文本优化成功',
  'optimization_failed': '优化失败',
  'recognizing_text': '正在识别文字...',
  'ocr_failed': 'OCR识别失败',
  'enter_title': '请输入标题',
  'enter_text': '请输入或导入文本',
  'no_sentences': '未找到句子',
  'sentences_detected': '检测到 %d 个句子',
  'text_opt_requires_llm': '请先在设置中配置AI服务商',

  // Reader
  'play_all': '全部播放',
  'stop': '停止',
  'single_mode': '单句',
  'continuous_mode': '连续',
  'loop_mode': '循环',
  'play_mode': '播放模式',
  'select_all': '全选',
  'deselect': '取消全选',
  'delete_selected': '删除所选',
  'delete_sentences_title': '删除句子',
  'delete_sentences_confirm': '确定删除 %d 个句子？',
  'delete_sentence_title': '删除句子',
  'delete_sentence_confirm': '确定删除此句子？',
  'edit_sentence': '编辑句子',
  'add_sentence': '添加句子',
  'speaker_optional': '说话人（可选）',
  'text': '文本',

  // Settings
  'settings_language': '应用语言',
  'settings_tts': '语音合成 (TTS)',
  'settings_ocr': '文字识别 (OCR)',
  'settings_text_opt': '文本优化',
  'settings_providers': 'AI服务商',
  'settings_manage_providers': '管理服务商',

  'tts_mode': '语音模式',
  'tts_system': '系统TTS',
  'tts_system_desc': '使用系统内置语音合成（离线）',
  'tts_traditional': '云端TTS',
  'tts_traditional_desc': 'Azure / Google Cloud 语音服务',
  'tts_llm': 'LLM语音',
  'tts_llm_desc': 'OpenAI TTS / 兼容API',
  'tts_provider': '语音服务商',
  'tts_voice': '音色',
  'tts_model': '模型',
  'tts_model_hint': '例如 gpt-4o-mini-tts',
  'tts_voice_hint_traditional': '例如 en-US-JennyNeural',
  'tts_voice_hint_llm': '例如 alloy, nova, shimmer',
  'tts_test': '测试语音',
  'tts_engine': '语音引擎',
  'tts_engine_default': '默认',
  'tts_open_system_settings': '打开系统TTS设置',
  'tts_open_system_settings_desc': '配置TTS引擎、下载语音数据',
  'tts_no_engine': '未找到TTS引擎',
  'tts_test_timeout': '语音测试超时，请打开系统TTS设置检查引擎配置。',
  'tts_system_available': '可用',
  'tts_system_config': '系统TTS设置',
  'tts_speech_rate': '语速',
  'tts_pitch': '音调',
  'tts_language': '语言',

  'ocr_mode': 'OCR模式',
  'ocr_mlkit': 'ML Kit（离线）',
  'ocr_mlkit_desc': 'Google ML Kit - 无需联网',
  'ocr_llm': 'LLM视觉',
  'ocr_llm_desc': '使用多模态大模型提取文字',
  'ocr_provider': 'OCR服务商',
  'ocr_model': '模型',
  'ocr_model_hint': '例如 gpt-4o, gemini-2.0-flash',

  'text_opt_enable': '启用文本优化',
  'text_opt_desc': '使用AI优化粘贴的对话文本',
  'text_opt_provider': '服务商',
  'text_opt_model': '模型',
  'text_opt_model_hint': '例如 gpt-4o-mini',

  // Providers
  'providers_title': 'AI服务商',
  'add_provider': '添加服务商',
  'edit_provider': '编辑服务商',
  'delete_provider': '删除服务商',
  'delete_provider_confirm': '确定删除服务商 "%s"？',
  'provider_type': '服务类型',
  'provider_name': '名称',
  'provider_api_key': 'API Key',
  'provider_base_url': 'API 地址',
  'provider_name_required': '请输入名称',
  'provider_key_required': '请输入API Key',
  'provider_test_success': '连接成功！',
  'provider_test_failed': '连接失败：%s',
  'no_providers': '暂无服务商',
  'no_providers_hint': '点击 + 添加AI服务商',
  'select_provider': '选择服务商',
  'no_provider_selected': '未选择服务商',
  'configure_provider_first': '请先在设置中添加AI服务商',

  // Theme mode
  'theme_mode': '颜色模式',
  'theme_system': '跟随系统',
  'theme_light': '浅色',
  'theme_dark': '深色',

  // Provider editor extras
  'available_models': '可用模型',
  'fetch_models': '获取模型列表',
  'no_models_fetched': '暂未获取模型',
  'test_model': '测试模型',
  'test_model_hint': '选择或输入用于测试的模型',

  // Custom prompts
  'ocr_custom_prompt': '自定义OCR提示词',
  'text_opt_custom_prompt': '自定义优化提示词',
  'reset_to_default': '重置为默认',
  'custom_prompt_hint': '留空则使用默认提示词',

  // About
  'about_github': 'GitHub 项目地址',
  'copied': '已复制！',
};
