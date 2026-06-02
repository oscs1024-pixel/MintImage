import 'package:drift/drift.dart';

import '../models/favorite_folder.dart';
import 'app_database.dart';

class FavoriteFolderSnapshot {
  const FavoriteFolderSnapshot({
    required this.folders,
    required this.memberships,
  });

  final List<FavoriteFolder> folders;
  final List<FavoriteFolderMembership> memberships;
}

class FavoriteFolderDao {
  const FavoriteFolderDao(this.database);

  final AppDatabase database;

  Future<void> ensureDefaultFolderAndMigrateLegacyFavorites() async {
    await database.transaction(() async {
      await _ensureDefaultFolder();

      final favoritedRecords = await (database.select(
        database.imageRecordsTable,
      )..where((table) => table.isFavorite.equals(true))).get();
      if (favoritedRecords.isEmpty) {
        return;
      }

      await database.batch((batch) {
        batch.insertAll(
          database.favoriteFolderItemsTable,
          favoritedRecords.map(
            (record) => FavoriteFolderItemsTableCompanion.insert(
              folderId: defaultFavoriteFolderId,
              recordId: record.id,
              createdAt: DateTime.now(),
            ),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      });
    });
  }

  Future<FavoriteFolderSnapshot> loadSnapshot() async {
    final folderRows =
        await (database.select(database.favoriteFoldersTable)..orderBy([
              (table) => OrderingTerm.desc(table.isDefault),
              (table) => OrderingTerm.asc(table.createdAt),
            ]))
            .get();
    final membershipRows = await database
        .select(database.favoriteFolderItemsTable)
        .get();

    return FavoriteFolderSnapshot(
      folders: folderRows
          .map(
            (row) => FavoriteFolder(
              id: row.id,
              title: row.title,
              isDefault: row.isDefault,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
      memberships: membershipRows
          .map(
            (row) => FavoriteFolderMembership(
              folderId: row.folderId,
              recordId: row.recordId,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> createFolder(FavoriteFolder folder) async {
    await database
        .into(database.favoriteFoldersTable)
        .insert(
          FavoriteFoldersTableCompanion.insert(
            id: folder.id,
            title: folder.title,
            isDefault: Value(folder.isDefault),
            createdAt: folder.createdAt,
          ),
        );
  }

  Future<List<String>> deleteFolder(String id) async {
    final memberships = await (database.select(
      database.favoriteFolderItemsTable,
    )..where((table) => table.folderId.equals(id))).get();
    await (database.delete(
      database.favoriteFoldersTable,
    )..where((table) => table.id.equals(id))).go();
    return memberships.map((item) => item.recordId).toList(growable: false);
  }

  Future<bool> toggleRecordInFolder({
    required String folderId,
    required String recordId,
  }) async {
    final existing =
        await (database.select(database.favoriteFolderItemsTable)..where(
              (table) =>
                  table.folderId.equals(folderId) &
                  table.recordId.equals(recordId),
            ))
            .getSingleOrNull();

    if (existing != null) {
      await (database.delete(database.favoriteFolderItemsTable)..where(
            (table) =>
                table.folderId.equals(folderId) &
                table.recordId.equals(recordId),
          ))
          .go();
      return false;
    }

    await database
        .into(database.favoriteFolderItemsTable)
        .insert(
          FavoriteFolderItemsTableCompanion.insert(
            folderId: folderId,
            recordId: recordId,
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return true;
  }

  Future<void> addRecordsToFolder({
    required String folderId,
    required List<String> recordIds,
  }) async {
    if (recordIds.isEmpty) {
      return;
    }

    await database.batch((batch) {
      batch.insertAll(
        database.favoriteFolderItemsTable,
        recordIds.map(
          (id) => FavoriteFolderItemsTableCompanion.insert(
            folderId: folderId,
            recordId: id,
            createdAt: DateTime.now(),
          ),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> replaceSnapshot(FavoriteFolderSnapshot snapshot) async {
    await database.delete(database.favoriteFolderItemsTable).go();
    await database.delete(database.favoriteFoldersTable).go();

    final hasDefaultFolder = snapshot.folders.any(
      (folder) => folder.id == defaultFavoriteFolderId || folder.isDefault,
    );
    final folders = [
      if (!hasDefaultFolder)
        FavoriteFolder(
          id: defaultFavoriteFolderId,
          title: defaultFavoriteFolderTitle,
          isDefault: true,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ...snapshot.folders,
    ];

    await database.batch((batch) {
      batch.insertAll(
        database.favoriteFoldersTable,
        folders.map(
          (folder) => FavoriteFoldersTableCompanion.insert(
            id: folder.id,
            title: folder.title,
            isDefault: Value(folder.isDefault),
            createdAt: folder.createdAt,
          ),
        ),
      );
      if (snapshot.memberships.isNotEmpty) {
        batch.insertAll(
          database.favoriteFolderItemsTable,
          snapshot.memberships.map(
            (membership) => FavoriteFolderItemsTableCompanion.insert(
              folderId: membership.folderId,
              recordId: membership.recordId,
              createdAt: membership.createdAt,
            ),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<void> setRecordFavoriteFlags(Map<String, bool> flags) async {
    if (flags.isEmpty) {
      return;
    }

    await database.batch((batch) {
      for (final entry in flags.entries) {
        batch.update(
          database.imageRecordsTable,
          ImageRecordsTableCompanion(isFavorite: Value(entry.value)),
          where: (table) => table.id.equals(entry.key),
        );
      }
    });
  }

  Future<void> _ensureDefaultFolder() async {
    final existing =
        await (database.select(database.favoriteFoldersTable)
              ..where((table) => table.id.equals(defaultFavoriteFolderId)))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }

    await database
        .into(database.favoriteFoldersTable)
        .insert(
          FavoriteFoldersTableCompanion.insert(
            id: defaultFavoriteFolderId,
            title: defaultFavoriteFolderTitle,
            isDefault: const Value(true),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
  }
}
