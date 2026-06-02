import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../models/settings_model.dart';

const _latestBackupFileName = 'mint_image_latest.mintbackup';

class WebDavBackupException implements Exception {
  const WebDavBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebDavBackupService {
  WebDavBackupService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> testConnection(WebDavBackupConfig config) async {
    _ensureConfigured(config);
    final response = await _dio.request<void>(
      _normalizedBaseUrl(config.baseUrl),
      options: Options(
        method: 'PROPFIND',
        headers: {..._headers(config), 'Depth': '0'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      throw const WebDavBackupException('WebDAV 认证失败，请检查用户名和密码。');
    }
    if (status == 404) {
      throw const WebDavBackupException('WebDAV 地址不存在，请检查地址。');
    }
    if (status == 200 || status == 207 || status == 204) {
      return;
    }
    throw WebDavBackupException('WebDAV 连接测试失败，状态码 ${status ?? '未知'}。');
  }

  Future<void> uploadLatestBackup(
    File archiveFile,
    WebDavBackupConfig config,
  ) async {
    _ensureConfigured(config);
    if (!await archiveFile.exists()) {
      throw const WebDavBackupException('备份文件不存在。');
    }

    await _ensureRemoteDirectory(config);
    final response = await _dio.put<List<int>>(
      _latestBackupUrl(config),
      data: await archiveFile.readAsBytes(),
      options: Options(
        headers: _headers(config),
        contentType: 'application/octet-stream',
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (!_isSuccessful(response.statusCode)) {
      throw WebDavBackupException(
        '上传 WebDAV 失败，状态码 ${response.statusCode ?? '未知'}。',
      );
    }
  }

  Future<File> downloadLatestBackup(
    WebDavBackupConfig config,
    Directory outputDirectory,
  ) async {
    _ensureConfigured(config);
    await outputDirectory.create(recursive: true);
    final response = await _dio.get<List<int>>(
      _latestBackupUrl(config),
      options: Options(
        headers: _headers(config),
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 404) {
      throw const WebDavBackupException('WebDAV 上还没有备份文件。');
    }
    if (!_isSuccessful(response.statusCode)) {
      throw WebDavBackupException(
        '下载 WebDAV 备份失败，状态码 ${response.statusCode ?? '未知'}。',
      );
    }

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const WebDavBackupException('WebDAV 备份文件为空。');
    }

    final file = File(p.join(outputDirectory.path, _latestBackupFileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _ensureRemoteDirectory(WebDavBackupConfig config) async {
    final segments = _pathSegments(config.remoteDirectory);
    var current = _normalizedBaseUrl(config.baseUrl);
    for (final segment in segments) {
      current = '$current/${Uri.encodeComponent(segment)}';
      final response = await _dio.request<void>(
        current,
        options: Options(
          method: 'MKCOL',
          headers: _headers(config),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final status = response.statusCode;
      if (status == 201 || status == 405) {
        continue;
      }
      if (status == 401 || status == 403) {
        throw const WebDavBackupException('WebDAV 认证失败，请检查用户名和密码。');
      }
      if (status != null && status >= 200 && status < 300) {
        continue;
      }
      throw WebDavBackupException('创建 WebDAV 目录失败，状态码 ${status ?? '未知'}。');
    }
  }

  String _latestBackupUrl(WebDavBackupConfig config) {
    final directory = _pathSegments(
      config.remoteDirectory,
    ).map(Uri.encodeComponent).join('/');
    final baseUrl = _normalizedBaseUrl(config.baseUrl);
    return directory.isEmpty
        ? '$baseUrl/$_latestBackupFileName'
        : '$baseUrl/$directory/$_latestBackupFileName';
  }

  Map<String, String> _headers(WebDavBackupConfig config) {
    final username = config.username.trim();
    final password = config.password;
    if (username.isEmpty && password.isEmpty) {
      return const {};
    }

    return {
      HttpHeaders.authorizationHeader:
          'Basic ${base64Encode(utf8.encode('$username:$password'))}',
    };
  }

  void _ensureConfigured(WebDavBackupConfig config) {
    if (!config.isConfigured) {
      throw const WebDavBackupException('请先配置 WebDAV 地址和远端目录。');
    }
  }

  bool _isSuccessful(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  List<String> _pathSegments(String value) {
    return value
        .split(RegExp(r'[\\/]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizedBaseUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }
}
