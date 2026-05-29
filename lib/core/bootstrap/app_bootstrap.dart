import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../database/favorite_folder_dao.dart';
import '../database/image_record_dao.dart';
import '../models/image_record.dart';
import '../models/settings_model.dart';
import '../providers/settings_provider.dart';

class AppBootstrap {
  AppBootstrap({
    required this.database,
    required this.imageRecordDao,
    required this.favoriteFolderDao,
    required this.sharedPreferences,
    required this.initialSettings,
    required this.initialRecords,
    required this.initialFavoriteFolderSnapshot,
  });

  final AppDatabase database;
  final ImageRecordDao imageRecordDao;
  final FavoriteFolderDao favoriteFolderDao;
  final SharedPreferences sharedPreferences;
  final SettingsModel initialSettings;
  final List<ImageRecord> initialRecords;
  final FavoriteFolderSnapshot initialFavoriteFolderSnapshot;

  static Future<AppBootstrap> load() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final database = AppDatabase();
    final imageRecordDao = ImageRecordDao(database);
    final favoriteFolderDao = FavoriteFolderDao(database);
    await favoriteFolderDao.ensureDefaultFolderAndMigrateLegacyFavorites();

    return AppBootstrap(
      database: database,
      imageRecordDao: imageRecordDao,
      favoriteFolderDao: favoriteFolderDao,
      sharedPreferences: sharedPreferences,
      initialSettings: SettingsController.loadFromPreferences(
        sharedPreferences,
      ),
      initialRecords: await _loadRecoveredRecords(imageRecordDao),
      initialFavoriteFolderSnapshot: await favoriteFolderDao.loadSnapshot(),
    );
  }

  static Future<List<ImageRecord>> _loadRecoveredRecords(
    ImageRecordDao imageRecordDao,
  ) async {
    final storedRecords = await imageRecordDao.loadAll();
    var hasRecoveredRecords = false;
    final recoveredRecords = <ImageRecord>[];

    for (final record in storedRecords) {
      final recoveredRecord = record.recoverInterruptedGeneration();
      if (!identical(recoveredRecord, record)) {
        hasRecoveredRecords = true;
      }
      recoveredRecords.add(recoveredRecord);
    }

    if (hasRecoveredRecords) {
      await imageRecordDao.upsertAll(recoveredRecords);
    }

    return recoveredRecords;
  }
}
