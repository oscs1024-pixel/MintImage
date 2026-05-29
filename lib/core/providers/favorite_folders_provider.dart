import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../database/favorite_folder_dao.dart';
import '../models/favorite_folder.dart';
import '../models/image_record.dart';
import 'app_providers.dart';
import 'image_list_provider.dart';

const _uuid = Uuid();
const _maxPreviewRecords = 12;

final favoriteFoldersProvider =
    StateNotifierProvider<FavoriteFolderController, FavoriteFoldersState>((
      ref,
    ) {
      return FavoriteFolderController(ref);
    });

class FavoriteFoldersState {
  const FavoriteFoldersState({
    required this.folders,
    required this.recordIdsByFolder,
  });

  const FavoriteFoldersState.empty()
    : folders = const [],
      recordIdsByFolder = const {};

  final List<FavoriteFolderSummary> folders;
  final Map<String, Set<String>> recordIdsByFolder;

  bool containsFolder(String folderId) {
    return folders.any((summary) => summary.id == folderId);
  }

  FavoriteFolderSummary? folderById(String folderId) {
    for (final folder in folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    return null;
  }

  Set<String> recordIdsForFolder(String folderId) {
    return recordIdsByFolder[folderId] ?? const <String>{};
  }

  Set<String> folderIdsForRecord(String recordId) {
    return {
      for (final entry in recordIdsByFolder.entries)
        if (entry.value.contains(recordId)) entry.key,
    };
  }
}

class FavoriteFolderController extends StateNotifier<FavoriteFoldersState> {
  FavoriteFolderController(this._ref)
    : super(const FavoriteFoldersState.empty()) {
    final snapshot = _ref.read(initialFavoriteFolderSnapshotProvider);
    _folders = snapshot.folders.isEmpty
        ? [
            FavoriteFolder(
              id: defaultFavoriteFolderId,
              title: defaultFavoriteFolderTitle,
              isDefault: true,
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ]
        : snapshot.folders;
    _memberships = snapshot.memberships;
    _rebuildState();
    _ref.listen<List<ImageRecord>>(imageListProvider, (previous, next) {
      _rebuildState();
    });
  }

  final Ref _ref;
  late List<FavoriteFolder> _folders;
  late List<FavoriteFolderMembership> _memberships;

  FavoriteFolderDao get _dao => _ref.read(favoriteFolderDaoProvider);

  Future<bool> createFolder(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty || _hasFolderTitle(title)) {
      return false;
    }

    final folder = FavoriteFolder(
      id: _uuid.v4(),
      title: title,
      isDefault: false,
      createdAt: DateTime.now(),
    );
    await _dao.createFolder(folder);
    _folders = _sortedFolders([..._folders, folder]);
    _rebuildState();
    return true;
  }

  Future<void> deleteFolder(String folderId) async {
    final folder = _folderById(folderId);
    if (folder == null || folder.isDefault) {
      return;
    }

    final affectedRecordIds = await _dao.deleteFolder(folderId);
    _folders = _folders.where((item) => item.id != folderId).toList();
    _memberships = _memberships
        .where((item) => item.folderId != folderId)
        .toList();
    await _syncFavoriteFlags(affectedRecordIds);
    _rebuildState();
  }

  Future<void> toggleRecordInFolder({
    required String folderId,
    required String recordId,
  }) async {
    if (_folderById(folderId) == null) {
      return;
    }

    final added = await _dao.toggleRecordInFolder(
      folderId: folderId,
      recordId: recordId,
    );
    if (added) {
      _memberships = [
        ..._memberships,
        FavoriteFolderMembership(
          folderId: folderId,
          recordId: recordId,
          createdAt: DateTime.now(),
        ),
      ];
    } else {
      _memberships = _memberships
          .where(
            (item) => item.folderId != folderId || item.recordId != recordId,
          )
          .toList();
    }
    await _syncFavoriteFlags([recordId]);
    _rebuildState();
  }

  Future<void> addRecordsToFolder({
    required String folderId,
    required List<String> recordIds,
  }) async {
    if (recordIds.isEmpty || _folderById(folderId) == null) {
      return;
    }

    await _dao.addRecordsToFolder(folderId: folderId, recordIds: recordIds);
    final existing = {
      for (final item in _memberships) '${item.folderId}/${item.recordId}',
    };
    final createdAt = DateTime.now();
    _memberships = [
      ..._memberships,
      for (final recordId in recordIds)
        if (!existing.contains('$folderId/$recordId'))
          FavoriteFolderMembership(
            folderId: folderId,
            recordId: recordId,
            createdAt: createdAt,
          ),
    ];
    await _syncFavoriteFlags(recordIds);
    _rebuildState();
  }

  bool _hasFolderTitle(String title) {
    final normalized = title.toLowerCase();
    return _folders.any((folder) => folder.title.toLowerCase() == normalized);
  }

  FavoriteFolder? _folderById(String folderId) {
    for (final folder in _folders) {
      if (folder.id == folderId) {
        return folder;
      }
    }
    return null;
  }

  Future<void> _syncFavoriteFlags(List<String> recordIds) async {
    final uniqueRecordIds = recordIds.toSet();
    final flags = {
      for (final recordId in uniqueRecordIds)
        recordId: _memberships.any((item) => item.recordId == recordId),
    };
    await _dao.setRecordFavoriteFlags(flags);
    await _ref.read(imageListProvider.notifier).reload();
  }

  void _rebuildState() {
    final records = _ref.read(imageListProvider);
    final recordsById = {for (final record in records) record.id: record};
    final recordIdsByFolder = <String, Set<String>>{};
    for (final folder in _folders) {
      recordIdsByFolder[folder.id] = <String>{};
    }
    for (final item in _memberships) {
      if (recordsById.containsKey(item.recordId)) {
        recordIdsByFolder.putIfAbsent(item.folderId, () => <String>{});
        recordIdsByFolder[item.folderId]!.add(item.recordId);
      }
    }

    final summaries = _sortedFolders(_folders)
        .map((folder) {
          final ids = recordIdsByFolder[folder.id] ?? const <String>{};
          final folderRecords = records
              .where((record) => ids.contains(record.id))
              .toList(growable: false);
          return FavoriteFolderSummary(
            folder: folder,
            recordCount: folderRecords.length,
            previewRecords: folderRecords.take(_maxPreviewRecords).toList(),
          );
        })
        .toList(growable: false);

    state = FavoriteFoldersState(
      folders: summaries,
      recordIdsByFolder: {
        for (final entry in recordIdsByFolder.entries)
          entry.key: Set.unmodifiable(entry.value),
      },
    );
  }

  List<FavoriteFolder> _sortedFolders(List<FavoriteFolder> folders) {
    final sorted = [...folders];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }
}
