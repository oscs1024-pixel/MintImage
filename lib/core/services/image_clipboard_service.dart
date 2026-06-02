import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/image_record.dart';

class ImageClipboardService {
  const ImageClipboardService();

  static const MethodChannel _channel = MethodChannel(
    'mint_image/image_clipboard',
  );

  Future<void> copyRecordImage(ImageRecord record) async {
    if (kIsWeb || (!Platform.isMacOS && !Platform.isWindows)) {
      throw const ImageClipboardException('当前平台不支持复制图片。');
    }

    final path = await _prepareClipboardFile(record);
    await _channel.invokeMethod<void>('copyImageFile', {'path': path});
  }

  Future<String?> readImageFileFromClipboard() async {
    if (kIsWeb || (!Platform.isMacOS && !Platform.isWindows)) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod<Object?>('readImageFile');
      if (result is! Map) {
        return null;
      }
      final path = result['path'];
      if (path is String && path.trim().isNotEmpty) {
        return path;
      }
      return null;
    } on PlatformException catch (error) {
      throw ImageClipboardException(error.message ?? '读取剪贴板图片失败。');
    }
  }

  Future<Uint8List> _loadEncodedBytes(ImageRecord record) async {
    final localPath = record.resultImagePath ?? record.sourceImagePath;
    if (localPath != null && File(localPath).existsSync()) {
      return File(localPath).readAsBytes();
    }

    final b64 = record.resultB64;
    if (b64 != null && b64.trim().isNotEmpty) {
      return base64Decode(_stripDataUrlPrefix(b64.trim()));
    }

    final url = record.resultImageUrl;
    if (url != null && url.trim().isNotEmpty) {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data != null && data.isNotEmpty) {
        return Uint8List.fromList(data);
      }
    }

    throw const ImageClipboardException('这条记录没有可复制的图片。');
  }

  Future<String> _prepareClipboardFile(ImageRecord record) async {
    final localPath = record.resultImagePath ?? record.sourceImagePath;
    if (localPath != null && File(localPath).existsSync()) {
      return localPath;
    }

    final encodedBytes = await _loadEncodedBytes(record);
    final tempDirectory = await getTemporaryDirectory();
    final safeId = record.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final extension = _clipboardFileExtension(record);
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'mint_image_clipboard_$safeId.$extension',
    );
    await file.writeAsBytes(encodedBytes, flush: true);
    return file.path;
  }

  String _stripDataUrlPrefix(String value) {
    final commaIndex = value.indexOf(',');
    if (commaIndex == -1 ||
        !value.substring(0, commaIndex).contains('base64')) {
      return value;
    }
    return value.substring(commaIndex + 1);
  }

  String _clipboardFileExtension(ImageRecord record) {
    final outputFormat = record.outputFormat.trim().toLowerCase();
    if (outputFormat == 'png' ||
        outputFormat == 'jpg' ||
        outputFormat == 'jpeg' ||
        outputFormat == 'webp') {
      return outputFormat == 'jpg' ? 'jpeg' : outputFormat;
    }

    final uri = Uri.tryParse(record.resultImageUrl?.trim() ?? '');
    final lastSegment = uri == null || uri.pathSegments.isEmpty
        ? ''
        : uri.pathSegments.last;
    final extension = lastSegment.contains('.')
        ? lastSegment.split('.').last.toLowerCase()
        : '';
    if (extension == 'png' ||
        extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'webp') {
      return extension == 'jpg' ? 'jpeg' : extension;
    }

    return 'png';
  }
}

class ImageClipboardException implements Exception {
  const ImageClipboardException(this.message);

  final String message;

  @override
  String toString() => message;
}
