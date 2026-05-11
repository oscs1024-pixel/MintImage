import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/providers/app_providers.dart';
import 'core/services/background_generation_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/request_log_service.dart';
import 'features/logs/log_viewer_app.dart';

Future<void> main([List<String> args = const []]) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.contains('--log-window')) {
    final requestLogService = await RequestLogService.load();
    runApp(
      ProviderScope(
        overrides: [
          requestLogServiceProvider.overrideWithValue(requestLogService),
        ],
        child: const LogViewerApp(),
      ),
    );
    return;
  }

  final bootstrap = await AppBootstrap.load();
  final requestLogService = await RequestLogService.load(reset: true);
  await notificationService.initialize();
  await backgroundGenerationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          bootstrap.sharedPreferences,
        ),
        appDatabaseProvider.overrideWithValue(bootstrap.database),
        imageRecordDaoProvider.overrideWithValue(bootstrap.imageRecordDao),
        initialSettingsModelProvider.overrideWithValue(
          bootstrap.initialSettings,
        ),
        initialImageRecordsProvider.overrideWithValue(bootstrap.initialRecords),
        requestLogServiceProvider.overrideWithValue(requestLogService),
      ],
      child: const GptImageApp(),
    ),
  );
}
