import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/settings_model.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';

class PromptOptimizationProfileEditPage extends ConsumerStatefulWidget {
  const PromptOptimizationProfileEditPage({super.key, this.profile});

  final PromptOptimizationProfile? profile;

  @override
  ConsumerState<PromptOptimizationProfileEditPage> createState() =>
      _PromptOptimizationProfileEditPageState();
}

class _PromptOptimizationProfileEditPageState
    extends ConsumerState<PromptOptimizationProfileEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _obscureApiKey = true;
  late PromptOptimizationProtocol _protocol;

  PromptOptimizationProfile? get _editingProfile => widget.profile;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final profile = _editingProfile;

    _protocol = profile?.protocol ?? PromptOptimizationProtocol.openAiResponses;
    _nameController.text =
        profile?.name ??
        '优化配置 ${settings.promptOptimizationProfiles.length + 1}';
    _baseUrlController.text = profile?.baseUrl ?? _protocol.defaultBaseUrl;
    _apiKeyController.text = profile?.apiKey ?? '';
    _modelController.text = profile?.model ?? _protocol.defaultModel;

    _baseUrlController.addListener(_refresh);
    _modelController.addListener(_refresh);
  }

  @override
  void dispose() {
    _baseUrlController.removeListener(_refresh);
    _modelController.removeListener(_refresh);
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finalUrl = _previewEndpoint();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingProfile == null ? '新增提示词优化 API' : '编辑提示词优化 API'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppThemeTokens.canvas, AppThemeTokens.canvasTint],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: AppDecorations.card(radius: 24),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('连接信息', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      '这里维护提示词优化专用的协议、Base URL、模型名与 API Key。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PromptOptimizationProtocol>(
                      initialValue: _protocol,
                      decoration: const InputDecoration(labelText: '协议类型'),
                      items: [
                        for (final protocol
                            in PromptOptimizationProtocol.values)
                          DropdownMenuItem(
                            value: protocol,
                            child: Text(protocol.label),
                          ),
                      ],
                      onChanged: (protocol) {
                        if (protocol == null) {
                          return;
                        }
                        setState(() {
                          final previousProtocol = _protocol;
                          _protocol = protocol;
                          final baseUrl = _baseUrlController.text.trim();
                          if (baseUrl.isEmpty ||
                              baseUrl == previousProtocol.defaultBaseUrl) {
                            _baseUrlController.text = protocol.defaultBaseUrl;
                          }
                          final model = _modelController.text.trim();
                          if (model.isEmpty ||
                              model == previousProtocol.defaultModel) {
                            _modelController.text = protocol.defaultModel;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(labelText: 'Base URL'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入 Base URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppThemeTokens.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '最终请求接口：$finalUrl',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(labelText: '模型名'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入模型名';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  String _previewEndpoint() {
    final baseUrl = _baseUrlController.text.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final resolvedBaseUrl = baseUrl.isEmpty ? 'https://example.com' : baseUrl;

    return switch (_protocol) {
      PromptOptimizationProtocol.openAiChatCompletions => _appendVersionPath(
        resolvedBaseUrl,
        'v1',
        ['chat', 'completions'],
      ),
      PromptOptimizationProtocol.openAiResponses => _appendVersionPath(
        resolvedBaseUrl,
        'v1',
        ['responses'],
      ),
      PromptOptimizationProtocol.claudeMessages => _appendVersionPath(
        resolvedBaseUrl,
        'v1',
        ['messages'],
      ),
      PromptOptimizationProtocol.geminiGenerateContent =>
        _appendVersionPath(resolvedBaseUrl, 'v1beta', [
          'models/${_modelController.text.trim().isEmpty ? '{model}' : _modelController.text.trim()}',
        ], suffix: ':generateContent'),
    };
  }

  String _appendVersionPath(
    String baseUrl,
    String version,
    List<String> segments, {
    String suffix = '',
  }) {
    final normalizedSegments = [
      if (!baseUrl.endsWith('/$version')) version,
      ...segments,
    ];
    return '$baseUrl/${normalizedSegments.join('/')}$suffix';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(settingsProvider.notifier);
    final existing = _editingProfile;

    if (existing == null) {
      final created = await notifier.addPromptOptimizationProfile(
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
        protocol: _protocol,
      );
      await notifier.setActivePromptOptimizationProfile(created.id);
    } else {
      await notifier.updatePromptOptimizationProfile(
        existing.copyWith(
          name: _nameController.text.trim(),
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          model: _modelController.text.trim(),
          protocol: _protocol,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
