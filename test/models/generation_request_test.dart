import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/models/generation_request.dart';

void main() {
  group('GenerationRequest', () {
    test('serializes and deserializes correctly', () {
      const request = GenerationRequest(
        prompt: 'a futuristic skyline at sunrise',
        imagePaths: ['C:/tmp/source.png'],
        sizePreset: SizePreset.custom,
        customWidth: 2048,
        customHeight: 1152,
        quality: ImageQuality.high,
        count: 3,
        apiProfileId: 'profile-1',
      );

      final restored = GenerationRequest.fromJson(request.toJson());

      expect(restored.prompt, request.prompt);
      expect(restored.imagePaths, request.imagePaths);
      expect(restored.sizePreset, SizePreset.custom);
      expect(restored.customWidth, 2048);
      expect(restored.customHeight, 1152);
      expect(restored.quality, ImageQuality.high);
      expect(restored.count, 3);
      expect(restored.apiProfileId, 'profile-1');
      expect(restored.apiSize, '2048x1152');
    });

    test('maps presets to OpenAI-compatible size strings', () {
      const square = GenerationRequest(
        prompt: 'test',
        imagePaths: [],
        sizePreset: SizePreset.square1k,
        customWidth: 1024,
        customHeight: 1024,
        quality: ImageQuality.auto,
        count: 1,
        apiProfileId: 'default',
      );

      const wide4k = GenerationRequest(
        prompt: 'test',
        imagePaths: [],
        sizePreset: SizePreset.wide4k,
        customWidth: 1024,
        customHeight: 1024,
        quality: ImageQuality.auto,
        count: 1,
        apiProfileId: 'default',
      );

      expect(square.apiSize, '1024x1024');
      expect(wide4k.apiSize, '3840x2160');
    });

    test('falls back to auto quality for unknown or missing values', () {
      final unknownQuality = GenerationRequest.fromJson({
        'prompt': 'test',
        'imagePaths': const <String>[],
        'sizePreset': SizePreset.square1k.storageKey,
        'customWidth': 1024,
        'customHeight': 1024,
        'quality': 'unexpected',
        'count': 1,
        'apiProfileId': 'default',
      });
      final missingQuality = GenerationRequest.fromJson({
        'prompt': 'test',
        'imagePaths': const <String>[],
        'sizePreset': SizePreset.square1k.storageKey,
        'customWidth': 1024,
        'customHeight': 1024,
        'count': 1,
        'apiProfileId': 'default',
      });

      expect(unknownQuality.quality, ImageQuality.auto);
      expect(missingQuality.quality, ImageQuality.auto);
    });
  });
}
