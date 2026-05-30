import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/prompt_optimization_api.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  final runLive = Platform.environment['RUN_LIVE_PROMPT_OPTIMIZATION'] == '1';
  final runLiveClaude =
      Platform.environment['RUN_LIVE_CLAUDE_PROMPT_OPTIMIZATION'] == '1';
  final apiKey = Platform.environment['TEST_PROMPT_OPTIMIZATION_API_KEY'];
  final timeoutSeconds =
      int.tryParse(Platform.environment['TEST_TIMEOUT_SECONDS'] ?? '') ?? 120;

  final cases = [
    _LivePromptOptimizationCase(
      name: 'OpenAI Chat',
      baseUrl:
          Platform.environment['TEST_OPENAI_PROMPT_OPTIMIZATION_BASE_URL'] ??
          'https://right.codes/codex/v1',
      model:
          Platform.environment['TEST_OPENAI_PROMPT_OPTIMIZATION_MODEL'] ??
          'gpt-5.5',
      protocol: PromptOptimizationProtocol.openAiChatCompletions,
    ),
    _LivePromptOptimizationCase(
      name: 'OpenAI Responses',
      baseUrl:
          Platform.environment['TEST_OPENAI_PROMPT_OPTIMIZATION_BASE_URL'] ??
          'https://right.codes/codex/v1',
      model:
          Platform.environment['TEST_OPENAI_PROMPT_OPTIMIZATION_MODEL'] ??
          'gpt-5.5',
      protocol: PromptOptimizationProtocol.openAiResponses,
    ),
    _LivePromptOptimizationCase(
      name: 'Claude',
      baseUrl:
          Platform.environment['TEST_CLAUDE_PROMPT_OPTIMIZATION_BASE_URL'] ??
          'https://right.codes/claude',
      model:
          Platform.environment['TEST_CLAUDE_PROMPT_OPTIMIZATION_MODEL'] ??
          'claude-sonnet-4-6',
      protocol: PromptOptimizationProtocol.claudeMessages,
      requiresClaudeCodeCompatibleClient: true,
    ),
    _LivePromptOptimizationCase(
      name: 'Gemini',
      baseUrl:
          Platform.environment['TEST_GEMINI_PROMPT_OPTIMIZATION_BASE_URL'] ??
          'https://right.codes/gemini',
      model:
          Platform.environment['TEST_GEMINI_PROMPT_OPTIMIZATION_MODEL'] ??
          'gemini-2.5-flash',
      protocol: PromptOptimizationProtocol.geminiGenerateContent,
    ),
  ];

  for (final item in cases) {
    test(
      '${item.name} returns optimized prompt text',
      () async {
        final profile = PromptOptimizationProfile(
          id: item.name,
          name: item.name,
          baseUrl: item.baseUrl,
          apiKey: apiKey!,
          model: item.model,
          protocol: item.protocol,
        );

        final result = await const PromptOptimizationApi().optimize(
          prompt: '一只白猫坐在雨后的窗边',
          direction: PromptOptimizationDirection.strengthen,
          profile: profile,
          timeoutSeconds: timeoutSeconds,
        );

        expect(result.trim(), isNotEmpty);
      },
      skip:
          _skipReason(
            item,
            runLive: runLive,
            runLiveClaude: runLiveClaude,
            apiKey: apiKey,
          ) ??
          false,
      timeout: Timeout(Duration(seconds: timeoutSeconds + 30)),
    );
  }
}

String? _skipReason(
  _LivePromptOptimizationCase item, {
  required bool runLive,
  required bool runLiveClaude,
  required String? apiKey,
}) {
  if (!runLive || apiKey == null || apiKey.isEmpty) {
    return 'Set RUN_LIVE_PROMPT_OPTIMIZATION=1 and TEST_PROMPT_OPTIMIZATION_API_KEY.';
  }

  if (item.requiresClaudeCodeCompatibleClient && !runLiveClaude) {
    return 'Set RUN_LIVE_CLAUDE_PROMPT_OPTIMIZATION=1 only with a Claude Code compatible endpoint.';
  }

  return null;
}

class _LivePromptOptimizationCase {
  const _LivePromptOptimizationCase({
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.protocol,
    this.requiresClaudeCodeCompatibleClient = false,
  });

  final String name;
  final String baseUrl;
  final String model;
  final PromptOptimizationProtocol protocol;
  final bool requiresClaudeCodeCompatibleClient;
}
