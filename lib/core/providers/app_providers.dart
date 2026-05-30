import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/image_edit_api.dart';
import '../api/image_generation_api.dart';
import '../api/prompt_optimization_api.dart';
import '../database/app_database.dart';
import '../database/favorite_folder_dao.dart';
import '../database/image_record_dao.dart';
import '../models/image_record.dart';
import '../models/settings_model.dart';
import '../services/background_generation_service.dart';
import '../services/attachment_picker_service.dart';
import '../services/image_save_service.dart';
import '../services/image_storage_service.dart';
import '../services/notification_service.dart';
import '../services/request_log_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider not overridden'),
);

final requestLogServiceProvider = Provider<RequestLogService>(
  (ref) => throw UnimplementedError('requestLogServiceProvider not overridden'),
);

final imageRecordDaoProvider = Provider<ImageRecordDao>(
  (ref) => ImageRecordDao(ref.watch(appDatabaseProvider)),
);

final favoriteFolderDaoProvider = Provider<FavoriteFolderDao>(
  (ref) => FavoriteFolderDao(ref.watch(appDatabaseProvider)),
);

final imageGenerationApiProvider = Provider<ImageGenerationApi>(
  (ref) => ImageGenerationApi(
    requestLogService: ref.watch(requestLogServiceProvider),
  ),
);

final imageEditApiProvider = Provider<ImageEditApi>(
  (ref) =>
      ImageEditApi(requestLogService: ref.watch(requestLogServiceProvider)),
);

final promptOptimizationApiProvider = Provider<PromptOptimizationApi>(
  (ref) => PromptOptimizationApi(
    requestLogService: ref.watch(requestLogServiceProvider),
  ),
);

final imageStorageServiceProvider = Provider<ImageStorageService>(
  (ref) => const ImageStorageService(),
);

final imageSaveServiceProvider = Provider<ImageSaveService>(
  (ref) => const ImageSaveService(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => notificationService,
);

final backgroundGenerationServiceProvider =
    Provider<BackgroundGenerationService>((ref) => backgroundGenerationService);

final attachmentPickerServiceProvider = Provider<AttachmentPickerService>(
  (ref) => AttachmentPickerService(),
);

final initialSettingsModelProvider = Provider<SettingsModel>(
  (ref) => SettingsModel.initial(),
);

final initialImageRecordsProvider = Provider<List<ImageRecord>>(
  (ref) => const [],
);

final initialFavoriteFolderSnapshotProvider = Provider<FavoriteFolderSnapshot>(
  (ref) => const FavoriteFolderSnapshot(folders: [], memberships: []),
);
