import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_image/core/models/image_record.dart';
import 'package:mint_image/core/models/settings_model.dart';
import 'package:mint_image/core/providers/app_providers.dart';
import 'package:mint_image/features/image_list/image_cell.dart';
import 'package:mint_image/features/image_list/image_preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows error details when tapping failed status pill', (
    tester,
  ) async {
    await _pumpImageCell(
      tester,
      _record.copyWith(errorMessage: '接口返回 429：额度不足'),
    );

    await tester.tap(find.text('失败'));
    await tester.pumpAndSettle();

    expect(find.text('失败原因'), findsOneWidget);
    expect(find.text('接口返回 429：额度不足'), findsOneWidget);
  });

  testWidgets('shows regenerate action for completed records', (tester) async {
    var regenerated = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onRegenerate: () {
        regenerated = true;
      },
    );

    await tester.longPress(find.byType(ImageCell));
    await tester.pumpAndSettle();

    expect(find.text('再生成一张'), findsOneWidget);
    await tester.tap(find.text('再生成一张'));
    await tester.pumpAndSettle();

    expect(regenerated, isTrue);
  });

  testWidgets('shows append attachment action when record has a local image', (
    tester,
  ) async {
    var appended = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: [File('pubspec.yaml').absolute.path],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onAppendCurrentImageToAttachments: () {
        appended = true;
      },
    );

    await tester.longPress(find.byType(ImageCell));
    await tester.pumpAndSettle();

    expect(find.text('将此图添加到附件1'), findsOneWidget);
    await tester.tap(find.text('将此图添加到附件1'));
    await tester.pumpAndSettle();

    expect(appended, isTrue);
  });

  testWidgets('opens preview through preview navigation callback', (
    tester,
  ) async {
    var navigatedThroughCallback = false;
    await _pumpImageCell(
      tester,
      _record.copyWith(
        status: ImageRecordStatus.done,
        sourceImagePaths: const ['missing-preview-image.png'],
        errorMessage: null,
        clearErrorMessage: true,
      ),
      onPreviewNavigation: (navigate) async {
        navigatedThroughCallback = true;
        await navigate();
      },
    );

    final cellTopLeft = tester.getTopLeft(find.byType(ImageCell));
    await tester.tapAt(cellTopLeft + const Offset(120, 90));
    await tester.pumpAndSettle();

    expect(navigatedThroughCallback, isTrue);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
  });
}

Future<void> _pumpImageCell(
  WidgetTester tester,
  ImageRecord record, {
  VoidCallback? onRegenerate,
  VoidCallback? onAppendCurrentImageToAttachments,
  Future<void> Function(Future<void> Function() navigate)? onPreviewNavigation,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSettingsModelProvider.overrideWithValue(_settings),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 300,
              child: ImageCell(
                record: record,
                imageHeight: 180,
                onReusePrompt: () {},
                onReuseEdit: () {},
                onRegenerate: onRegenerate ?? () {},
                onRetry: () {},
                onCancel: () {},
                onDelete: () {},
                onToggleFavorite: () {},
                onPreviewNavigation:
                    onPreviewNavigation ?? (navigate) => navigate(),
                selectionMode: false,
                selected: false,
                onSelectionToggle: () {},
                currentAttachmentCount: 0,
                onAppendCurrentImageToAttachments:
                    onAppendCurrentImageToAttachments ?? () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _settings = SettingsModel(
  profiles: [_apiProfile],
  activeProfileId: 'api',
);

const _apiProfile = ApiProfile(
  id: 'api',
  name: 'API',
  baseUrl: 'https://api.openai.com',
  apiKey: 'test-key',
  model: 'gpt-image-2',
);

final _record = ImageRecord(
  id: 'record-error',
  prompt: '一张城市夜景',
  apiProfileId: 'api',
  sourceImagePath: null,
  sourceImagePaths: const [],
  resultImagePath: null,
  resultImageUrl: null,
  resultB64: null,
  width: 1024,
  height: 1024,
  quality: 'medium',
  outputFormat: 'png',
  model: 'gpt-image-2',
  status: ImageRecordStatus.error,
  errorMessage: null,
  rawApiResponseValue: null,
  createdAt: DateTime(2026, 5, 30, 12),
  durationMs: 1200,
  usedSingleImageFallback: false,
  isFavorite: false,
);
