import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundGenerationService {
  BackgroundGenerationService._();

  static final BackgroundGenerationService instance =
      BackgroundGenerationService._();

  static const String _channelId = 'gpt_image_background_service';
  static const bool _foregroundKeepAliveEnabled = false;

  bool _configured = false;

  Future<void> initialize() async {
    if (!_foregroundKeepAliveEnabled) {
      _configured = true;
      return;
    }

    if (_configured) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      _configured = true;
      return;
    }

    try {
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: backgroundServiceOnStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'GPT Image',
          initialNotificationContent: '生成任务运行中',
          foregroundServiceNotificationId: 112233,
          foregroundServiceTypes: const [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: backgroundServiceOnStart,
          onBackground: backgroundServiceOnBackground,
        ),
      );

      _configured = true;
    } catch (_) {}
  }

  Future<void> startIfNeeded() async {
    if (!_foregroundKeepAliveEnabled) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    await initialize();

    if (!_configured) {
      return;
    }

    try {
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    if (!_foregroundKeepAliveEnabled) {
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void backgroundServiceOnStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'GPT Image',
      content: '生成任务运行中',
    );
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> backgroundServiceOnBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

final backgroundGenerationService = BackgroundGenerationService.instance;
