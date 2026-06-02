import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/favorite_folder.dart';
import '../../core/models/image_record.dart';
import '../../core/providers/favorite_folders_provider.dart';
import '../../shared/theme.dart';


Future<String?> showFavoriteFolderBrowserSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _FavoriteFolderSheet(),
  );
}

Future<void> showFavoriteFolderRecordSheet(
  BuildContext context, {
  required ImageRecord record,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FavoriteFolderSheet(record: record),
  );
}

class _FavoriteFolderSheet extends ConsumerStatefulWidget {
  const _FavoriteFolderSheet({this.record});

  final ImageRecord? record;

  @override
  ConsumerState<_FavoriteFolderSheet> createState() =>
      _FavoriteFolderSheetState();
}

class _FavoriteFolderSheetState extends ConsumerState<_FavoriteFolderSheet> {
  final TextEditingController _folderController = TextEditingController();
  final FocusNode _folderFocusNode = FocusNode();
  bool _creating = false;
  String? _createError;

  bool get _isRecordMode => widget.record != null;

  @override
  void dispose() {
    _folderController.dispose();
    _folderFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoriteFoldersProvider);
    final folders = state.folders;
    final selectedFolderIds = widget.record == null
        ? const <String>{}
        : state.folderIdsForRecord(widget.record!.id);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isRecordMode ? '收藏到' : '收藏夹',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppThemeTokens.textPrimary,
                ),
              ),
              if (_isRecordMode) ...[
                const SizedBox(height: 4),
                Text(
                  '将结果收藏到：',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppThemeTokens.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return _FavoriteFolderRow(
                      folder: folder,
                      selected: selectedFolderIds.contains(folder.id),
                      recordMode: _isRecordMode,
                      onTap: () => _handleFolderTap(folder.id),
                      onLongPress: folder.isDefault
                          ? null
                          : () => _confirmDeleteFolder(folder),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _buildCreateRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRow(BuildContext context) {
    if (!_creating) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _creating = true;
            _createError = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _folderFocusNode.requestFocus();
            }
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppThemeTokens.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppThemeTokens.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppThemeTokens.primaryStrong),
              const SizedBox(width: 6),
              Text(
                '新建收藏夹',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppThemeTokens.primaryStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _folderController,
                focusNode: _folderFocusNode,
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _createFolder(),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '收藏夹名称',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CreateActionButton(
              tooltip: '创建',
              icon: Icons.check_rounded,
              color: AppThemeTokens.primaryStrong,
              onPressed: _createFolder,
            ),
            const SizedBox(width: 4),
            _CreateActionButton(
              tooltip: '取消',
              icon: Icons.close_rounded,
              color: AppThemeTokens.textSecondary,
              onPressed: _cancelCreate,
            ),
          ],
        ),
        if (_createError != null) ...[
          const SizedBox(height: 6),
          Text(
            _createError!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  void _handleFolderTap(String folderId) {
    final record = widget.record;
    if (record == null) {
      Navigator.of(context).pop(folderId);
      return;
    }

    ref
        .read(favoriteFoldersProvider.notifier)
        .toggleRecordInFolder(folderId: folderId, recordId: record.id);
  }

  Future<void> _createFolder() async {
    final created = await ref
        .read(favoriteFoldersProvider.notifier)
        .createFolder(_folderController.text);
    if (!mounted) {
      return;
    }
    if (!created) {
      setState(() {
        _createError = '名称不能为空，也不能和已有收藏夹重复。';
      });
      return;
    }

    _folderController.clear();
    setState(() {
      _creating = false;
      _createError = null;
    });
  }

  void _cancelCreate() {
    _folderController.clear();
    _folderFocusNode.unfocus();
    setState(() {
      _creating = false;
      _createError = null;
    });
  }

  Future<void> _confirmDeleteFolder(FavoriteFolderSummary folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除收藏夹'),
          content: Text('确认删除“${folder.title}”？其中的生成结果不会被删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(favoriteFoldersProvider.notifier).deleteFolder(folder.id);
  }
}

class _FavoriteFolderRow extends StatelessWidget {
  const _FavoriteFolderRow({
    required this.folder,
    required this.selected,
    required this.recordMode,
    required this.onTap,
    required this.onLongPress,
  });

  final FavoriteFolderSummary folder;
  final bool selected;
  final bool recordMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.orange.shade50
              : AppThemeTokens.surfaceSoft.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.orange.shade300 : AppThemeTokens.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${folder.title}（${folder.recordCount}）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppThemeTokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (recordMode && selected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Colors.orange.shade700,
              ),
            ],
            const SizedBox(width: 10),
            _FolderPreviewStrip(records: folder.previewRecords),
          ],
        ),
      ),
    );
  }
}

class _FolderPreviewStrip extends StatelessWidget {
  const _FolderPreviewStrip({required this.records});

  final List<ImageRecord> records;

  // Thumbnail size and layout constants
  static const double _thumbSize = 46.0;
  static const double _step = 29.0; // horizontal offset between cards
  static const int _maxShow = 4;

  // Per-slot visual properties (index 0 = back, 3 = front)
  static const _angles = [-0.22, -0.07, 0.07, 0.20]; // radians: ≈ -13°, -4°, +4°, +11°
  static const _yOffsets = [8.0, 3.0, -1.0, -5.0]; // vertical shift for depth feel
  static const _shadowAlphas = [0.08, 0.13, 0.19, 0.27];
  static const _shadowBlurs = [3.0, 5.0, 7.0, 10.0];

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return SizedBox(
        height: _thumbSize,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            '暂无收藏',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppThemeTokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final count = records.length.clamp(0, _maxShow);
    // Reserve extra width/height for rotated corners spilling outside the box
    final totalWidth = _step * (count - 1) + _thumbSize + 16.0;
    const totalHeight = _thumbSize + 20.0;
    const baseTop = 7.0;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Render back-to-front so later items paint on top
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * _step,
              top: baseTop + _yOffsets[i],
              child: Transform.rotate(
                angle: _angles[i],
                // Rotate from the bottom-center anchor → fan-out effect
                alignment: Alignment.bottomCenter,
                child: _buildCard(records[i], i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(ImageRecord record, int index) {
    return Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _shadowAlphas[index]),
            blurRadius: _shadowBlurs[index],
            spreadRadius: 0,
            offset: const Offset(1.0, 2.5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: AppThemeTokens.surfaceSoft,
          child: _buildImage(record),
        ),
      ),
    );
  }

  Widget _buildImage(ImageRecord record) {
    final localPath = record.resultImagePath ?? record.sourceImagePath;
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 100,
      );
    }

    final url = record.resultImageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: 100,
        maxWidthDiskCache: 100,
        placeholder: (_, _) => const ColoredBox(color: AppThemeTokens.surface),
        errorWidget: (_, _, _) =>
            const Icon(Icons.image_not_supported_rounded, size: 14),
      );
    }

    return const ColoredBox(
      color: AppThemeTokens.surfaceSoft,
      child: Center(child: Icon(Icons.broken_image_rounded, size: 14)),
    );
  }
}

class _CreateActionButton extends StatelessWidget {
  const _CreateActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: color,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
