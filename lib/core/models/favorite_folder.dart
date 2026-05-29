import 'image_record.dart';

const defaultFavoriteFolderId = 'default';
const defaultFavoriteFolderTitle = '默认';

class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.title,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool isDefault;
  final DateTime createdAt;
}

class FavoriteFolderMembership {
  const FavoriteFolderMembership({
    required this.folderId,
    required this.recordId,
    required this.createdAt,
  });

  final String folderId;
  final String recordId;
  final DateTime createdAt;
}

class FavoriteFolderSummary {
  const FavoriteFolderSummary({
    required this.folder,
    required this.recordCount,
    required this.previewRecords,
  });

  final FavoriteFolder folder;
  final int recordCount;
  final List<ImageRecord> previewRecords;

  String get id => folder.id;
  String get title => folder.title;
  bool get isDefault => folder.isDefault;
}
