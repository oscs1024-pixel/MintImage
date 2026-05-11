import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/openai_client.dart';

class ImageSaveService {
  const ImageSaveService();

  Future<String?> saveImage({
    required String suggestedFileName,
    String? localPath,
    String? imageUrl,
  }) async {
    final sourceFile = await _resolveSourceFile(
      suggestedFileName: suggestedFileName,
      localPath: localPath,
      imageUrl: imageUrl,
    );

    if (sourceFile == null) {
      throw const ApiException('没有可保存的图片文件。');
    }

    if (_usesDialogSaveOnMobile()) {
      return FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: sourceFile.path,
          mimeTypesFilter: const ['image/png', 'image/jpeg', 'image/webp'],
          localOnly: true,
        ),
      );
    }

    final bytes = await sourceFile.readAsBytes();
    return FilePicker.saveFile(
      dialogTitle: '保存图片',
      fileName: suggestedFileName,
      type: FileType.custom,
      allowedExtensions: [p.extension(suggestedFileName).replaceFirst('.', '')],
      bytes: bytes,
      lockParentWindow: true,
    );
  }

  Future<File?> _resolveSourceFile({
    required String suggestedFileName,
    String? localPath,
    String? imageUrl,
  }) async {
    if (localPath != null && await File(localPath).exists()) {
      return File(localPath);
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(imageUrl));
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('下载图片失败，状态码 ${response.statusCode}。');
    }

    final bytes = await consolidateHttpClientResponseBytes(response);
    final tempDirectory = await getTemporaryDirectory();
    final file = File(p.join(tempDirectory.path, suggestedFileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  bool _usesDialogSaveOnMobile() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }
}
