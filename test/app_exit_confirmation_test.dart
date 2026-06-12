import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mint_image/app.dart';
import 'package:mint_image/core/providers/generation_provider.dart';

const _windowClosePlatforms = TargetPlatformVariant({
  TargetPlatform.macOS,
  TargetPlatform.windows,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLifecycleListener fallback', () {
    testWidgets(
      'allows window close when no generation is running',
      (tester) async {
        await _pumpApp(tester);

        final response = await WidgetsBinding.instance.handleRequestAppExit();

        expect(response, AppExitResponse.exit);
        expect(find.text('确认退出？'), findsNothing);
      },
      variant: _windowClosePlatforms,
    );

    testWidgets(
      'asks for confirmation before closing during generation',
      (tester) async {
        await _pumpApp(
          tester,
          generationState: const GenerationState(
            activeRequestIds: {'active-record'},
          ),
        );

        final cancelResponse = WidgetsBinding.instance.handleRequestAppExit();
        await tester.pumpAndSettle();

        expect(find.text('确认退出？'), findsOneWidget);
        expect(find.text('当前仍有图片正在生成，退出会中断这些任务。'), findsOneWidget);

        await tester.tap(find.text('继续生成'));
        await tester.pumpAndSettle();

        expect(await cancelResponse, AppExitResponse.cancel);

        final exitResponse = WidgetsBinding.instance.handleRequestAppExit();
        await tester.pumpAndSettle();

        await tester.tap(find.text('退出'));
        await tester.pumpAndSettle();

        expect(await exitResponse, AppExitResponse.exit);
      },
      variant: _windowClosePlatforms,
    );
  });

  group('native window_lifecycle channel', () {
    testWidgets(
      'returns true immediately when no generation is running',
      (tester) async {
        await _pumpApp(tester);

        final allow = await _invokeOnCloseRequested(tester);

        expect(allow, isTrue);
        expect(find.text('确认退出？'), findsNothing);
      },
      variant: _windowClosePlatforms,
    );

    testWidgets(
      'blocks close and drives performClose after confirmation',
      (tester) async {
        final performCloseCalls = _capturePerformClose(tester);

        await _pumpApp(
          tester,
          generationState: const GenerationState(
            activeRequestIds: {'active-record'},
          ),
        );

        final pending = _invokeOnCloseRequested(tester);
        await tester.pumpAndSettle();

        // Native is told to wait (false) while the dialog is shown.
        expect(find.text('确认退出？'), findsOneWidget);

        await tester.tap(find.text('退出'));
        await tester.pumpAndSettle();

        expect(await pending, isFalse);
        expect(performCloseCalls, hasLength(1));
      },
      variant: _windowClosePlatforms,
    );

    testWidgets(
      'blocks close and does not exit when user keeps generating',
      (tester) async {
        final performCloseCalls = _capturePerformClose(tester);

        await _pumpApp(
          tester,
          generationState: const GenerationState(
            activeRequestIds: {'active-record'},
          ),
        );

        final pending = _invokeOnCloseRequested(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text('继续生成'));
        await tester.pumpAndSettle();

        expect(await pending, isFalse);
        expect(performCloseCalls, isEmpty);
      },
      variant: _windowClosePlatforms,
    );
  });
}

/// Drives the inbound `onCloseRequested` call the native runner would make and
/// returns the boolean the handler answers with.
Future<bool> _invokeOnCloseRequested(WidgetTester tester) async {
  final codec = windowLifecycleChannel.codec;
  final message = codec.encodeMethodCall(const MethodCall('onCloseRequested'));

  final reply = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        windowLifecycleChannel.name,
        message,
        (_) {},
      );

  if (reply == null) {
    return false;
  }
  return codec.decodeEnvelope(reply) as bool;
}

/// Captures outbound `performClose` calls the handler sends back to native.
List<MethodCall> _capturePerformClose(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowLifecycleChannel,
    (call) async {
      calls.add(call);
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowLifecycleChannel,
      null,
    );
  });
  return calls;
}

Future<void> _pumpApp(
  WidgetTester tester, {
  GenerationState generationState = const GenerationState(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        generationProvider.overrideWith(
          (ref) => _FakeGenerationController(ref, generationState),
        ),
      ],
      child: const GptImageApp(home: Scaffold(body: SizedBox.shrink())),
    ),
  );
  await tester.pump();
}

class _FakeGenerationController extends GenerationController {
  _FakeGenerationController(super.ref, GenerationState initialState) {
    state = initialState;
  }
}
