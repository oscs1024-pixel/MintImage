import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/main.dart' as app;
import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/providers/image_list_provider.dart';
import 'package:mint_image/core/providers/settings_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'sending a prompt creates a loading record',
    (tester) async {
      final configuredApiKey = Platform.environment['TEST_API_KEY'];
      expect(
        configuredApiKey,
        isNotNull,
        reason: 'Set TEST_API_KEY before running the smoke test.',
      );

      final settingsJson = jsonEncode({
        'profiles': [
          {
            'id': 'integration-profile',
            'name': 'Integration',
            'baseUrl':
                Platform.environment['TEST_BASE_URL'] ??
                'https://www.packyapi.com',
            'apiKey': configuredApiKey,
            'model': Platform.environment['TEST_MODEL'] ?? 'gpt-image-2',
          },
        ],
        'activeProfileId': 'integration-profile',
        'responseFormat': 'b64_json',
      });
      SharedPreferences.setMockInitialValues({
        'settings_model_v1': settingsJson,
      });

      await app.main();
      await tester.pump();

      final appRootDeadline = DateTime.now().add(const Duration(seconds: 10));
      final appRoot = find.byType(MaterialApp);
      while (DateTime.now().isBefore(appRootDeadline) &&
          appRoot.evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(appRoot, findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(appRoot),
        listen: false,
      );

      final settings = container.read(settingsProvider);
      expect(
        settings.activeProfile.apiKey.trim(),
        isNotEmpty,
        reason: 'The test environment must provide a configured API profile.',
      );

      await container.read(imageListProvider.notifier).clearHistory();
      await tester.pump();

      final promptField = find.byKey(const Key('prompt-input'));
      final sendButton = find.byKey(const Key('submit-generation-button'));
      const prompt = 'integration_blue_cube';

      expect(promptField, findsOneWidget);
      expect(sendButton, findsOneWidget);
      expect(find.text('请先设置 API Key'), findsNothing);

      await tester.enterText(promptField, prompt);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(sendButton);
      await tester.pump();

      expect(find.text(prompt), findsWidgets);

      final deadline = DateTime.now().add(const Duration(seconds: 30));

      while (DateTime.now().isBefore(deadline)) {
        final records = container.read(imageListProvider);
        final loadingRecord = records.where(
          (record) =>
              record.prompt == prompt &&
              record.status == ImageRecordStatus.loading,
        );

        if (loadingRecord.isNotEmpty) {
          await tester.pump();
          expect(find.text('生成中'), findsWidgets);
          expect(records, isNotEmpty);
          expect(records.first.prompt, prompt);
          expect(records.first.status, ImageRecordStatus.loading);
          return;
        }

        await tester.pump(const Duration(milliseconds: 250));
      }

      final visibleTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList();
      fail(
        'Generation did not enter loading state within 30 seconds. Visible text: $visibleTexts',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
