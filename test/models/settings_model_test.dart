import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/models/settings_model.dart';

void main() {
  test('initial settings use a 600 second timeout', () {
    final settings = SettingsModel.initial();

    expect(
      settings.requestTimeoutSeconds,
      SettingsModel.defaultRequestTimeoutSeconds,
    );
  });

  test('settings round-trip preserves request timeout', () {
    final settings = SettingsModel.initial().copyWith(
      requestTimeoutSeconds: 900,
    );

    final decoded = SettingsModel.decode(settings.encode());

    expect(decoded.requestTimeoutSeconds, 900);
  });
}
