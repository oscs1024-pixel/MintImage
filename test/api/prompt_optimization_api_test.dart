import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/prompt_optimization_api.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  group('PromptOptimizationApi', () {
    test(
      'uses OpenAI Chat Completions format and parses message text',
      () async {
        final server = await _startServer((request) async {
          expect(request.method, 'POST');
          expect(request.uri.path, '/v1/chat/completions');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer test-key',
          );
          final body = await _readJson(request);
          expect(body['model'], 'gpt-test');
          expect(body['messages'], isA<List>());

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'optimized chat prompt'},
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final result = await const PromptOptimizationApi().optimize(
          prompt: 'cat',
          direction: PromptOptimizationDirection.strengthen,
          profile: _profileFor(
            server,
            protocol: PromptOptimizationProtocol.openAiChatCompletions,
          ),
          timeoutSeconds: 30,
        );

        expect(result, 'optimized chat prompt');
      },
    );

    test('uses OpenAI Responses format and parses output_text', () async {
      final server = await _startServer((request) async {
        expect(request.uri.path, '/v1/responses');
        final body = await _readJson(request);
        expect(body['model'], 'gpt-test');
        expect(body['input'], isA<List>());
        expect(body['stream'], isTrue);

        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'response prompt'})}\n\n'
          'data: [DONE]\n\n',
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final result = await const PromptOptimizationApi().optimize(
        prompt: 'cat',
        direction: PromptOptimizationDirection.poetic,
        profile: _profileFor(
          server,
          protocol: PromptOptimizationProtocol.openAiResponses,
        ),
        timeoutSeconds: 30,
      );

      expect(result, 'response prompt');
    });

    test('uses Claude Messages format and parses content text', () async {
      final server = await _startServer((request) async {
        expect(request.uri.path, '/v1/messages');
        expect(request.headers.value('x-api-key'), 'test-key');
        final body = await _readJson(request);
        expect(body['model'], 'gpt-test');
        expect(body['stream'], isTrue);
        expect(body['messages'], isA<List>());
        final messages = body['messages'] as List;
        final firstMessage = messages.first as Map<String, dynamic>;
        expect(firstMessage['content'], isA<List>());

        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': 'claude prompt'},
          })}\n\n'
          'data: [DONE]\n\n',
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final result = await const PromptOptimizationApi().optimize(
        prompt: 'cat',
        direction: PromptOptimizationDirection.edgeExplore,
        profile: _profileFor(
          server,
          protocol: PromptOptimizationProtocol.claudeMessages,
        ),
        timeoutSeconds: 30,
      );

      expect(result, 'claude prompt');
    });

    test(
      'uses Gemini generateContent format and parses candidate text',
      () async {
        final server = await _startServer((request) async {
          expect(request.uri.path, '/v1beta/models/gpt-test:generateContent');
          expect(request.headers.value('x-goog-api-key'), 'test-key');
          final body = await _readJson(request);
          expect(body['contents'], isA<List>());

          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'gemini prompt'},
                    ],
                  },
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(server.close);

        final result = await const PromptOptimizationApi().optimize(
          prompt: 'cat',
          direction: PromptOptimizationDirection.strengthenToEnglish,
          profile: _profileFor(
            server,
            protocol: PromptOptimizationProtocol.geminiGenerateContent,
          ),
          timeoutSeconds: 30,
        );

        expect(result, 'gemini prompt');
      },
    );
  });
}

Future<HttpServer> _startServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  unawaited(
    server.forEach((request) async {
      await handler(request);
    }),
  );
  return server;
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

PromptOptimizationProfile _profileFor(
  HttpServer server, {
  required PromptOptimizationProtocol protocol,
}) {
  return PromptOptimizationProfile(
    id: 'optimizer',
    name: 'Optimizer',
    baseUrl: 'http://${server.address.host}:${server.port}',
    apiKey: 'test-key',
    model: 'gpt-test',
    protocol: protocol,
  );
}
