import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/api/model_list_api.dart';
import 'package:mint_image/core/models/settings_model.dart';

void main() {
  group('ModelListApi', () {
    test('fetches OpenAI compatible model ids from /v1/models', () async {
      final server = await _startServer((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/v1/models');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-key',
        );

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'id': 'gpt-image-2'},
              {'id': 'gpt-5.5'},
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final models = await const ModelListApi().fetchImageGenerationModels(
        profile: ApiProfile(
          id: 'api',
          name: 'API',
          baseUrl: 'http://${server.address.host}:${server.port}',
          apiKey: 'test-key',
          model: 'gpt-image-2',
        ),
        timeoutSeconds: 30,
      );

      expect(models, ['gpt-5.5', 'gpt-image-2']);
    });

    test('fetches Gemini models and strips models prefix', () async {
      final server = await _startServer((request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/v1beta/models');
        expect(request.headers.value('x-goog-api-key'), 'test-key');

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.5-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding-004',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(server.close);

      final models = await const ModelListApi().fetchPromptOptimizationModels(
        profile: PromptOptimizationProfile(
          id: 'optimizer',
          name: 'Optimizer',
          baseUrl: 'http://${server.address.host}:${server.port}',
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          protocol: PromptOptimizationProtocol.geminiGenerateContent,
        ),
        timeoutSeconds: 30,
      );

      expect(models, ['gemini-2.5-flash']);
    });
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
