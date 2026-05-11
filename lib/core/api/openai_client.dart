import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/settings_model.dart';
import '../services/request_log_service.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenAiClient {
  OpenAiClient(
    ApiProfile profile, {
    required int timeoutSeconds,
    RequestLogService? requestLogService,
  }) : _requestLogService = requestLogService,
       _dio = Dio(
         BaseOptions(
           baseUrl: profile.normalizedBaseUrl,
           connectTimeout: Duration(seconds: timeoutSeconds),
           sendTimeout: Duration(seconds: timeoutSeconds),
           receiveTimeout: Duration(seconds: timeoutSeconds),
           headers: {
             'Authorization': 'Bearer ${profile.apiKey.trim()}',
             'Accept': 'application/json',
           },
         ),
       );

  final Dio _dio;
  final RequestLogService? _requestLogService;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final title = 'POST $path';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '请求体:\n${_prettyJson(body)}',
      ),
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(contentType: Headers.jsonContentType),
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(response.data)}',
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    FormData formData, {
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    final title = 'POST $path';
    unawaited(
      _requestLogService?.logRequest(
        title,
        '请求地址: ${_dio.options.baseUrl}$path\n'
        '超时: ${_dio.options.connectTimeout?.inSeconds ?? 0} 秒\n'
        '表单字段:\n${_prettyJson(_fieldsMap(formData))}\n'
        '上传文件:\n${_fileSummary(formData)}',
      ),
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: formData,
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      unawaited(
        _requestLogService?.logResponse(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '状态码: ${response.statusCode ?? 'unknown'}\n'
          '响应体:\n${_summarizeData(response.data)}',
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      stopwatch.stop();
      final message = extractErrorMessage(error);
      unawaited(
        _requestLogService?.logError(
          title,
          '耗时: ${stopwatch.elapsedMilliseconds} ms\n'
          '错误: $message\n'
          '响应体:\n${_summarizeData(error.response?.data)}',
        ),
      );
      throw ApiException(message);
    }
  }

  static String extractErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? apiMessage;

    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      final nestedError = map['error'];

      if (nestedError is Map && nestedError['message'] is String) {
        apiMessage = nestedError['message'] as String;
      }

      apiMessage ??= switch (map['message']) {
        String value => value,
        _ => null,
      };
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      apiMessage = responseData.trim();
    }

    if (apiMessage != null && apiMessage.isNotEmpty) {
      return _withStatusCode(apiMessage, statusCode);
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '请求超时，请检查超时设置或稍后重试。';
      case DioExceptionType.connectionError:
        return _withStatusCode('网络连接失败，请检查网络或 Base URL。', statusCode);
      case DioExceptionType.badCertificate:
        return _withStatusCode('证书校验失败，请检查 HTTPS 配置。', statusCode);
      case DioExceptionType.badResponse:
        return _withStatusCode('请求失败，请检查接口返回。', statusCode);
      case DioExceptionType.cancel:
        return '请求已取消。';
      case DioExceptionType.unknown:
        return _withStatusCode(error.message ?? '请求失败，请稍后重试。', statusCode);
    }
  }

  static String _withStatusCode(String message, int? statusCode) {
    if (statusCode == null) {
      return message;
    }

    return 'HTTP $statusCode：$message';
  }

  Map<String, dynamic> _fieldsMap(FormData formData) {
    return {for (final field in formData.fields) field.key: field.value};
  }

  String _fileSummary(FormData formData) {
    final files = formData.files
        .map((item) => '${item.key}: ${item.value.filename ?? 'unknown'}')
        .toList();
    return files.isEmpty ? '(无)' : files.join('\n');
  }

  String _summarizeData(Object? data) {
    if (data == null) {
      return '(空)';
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final payload = map['data'];
      if (payload is List) {
        map['data'] = {'count': payload.length};
      }
      return _prettyJson(map);
    }

    return _truncate(data.toString());
  }

  String _prettyJson(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return _truncate(value.toString());
    }
  }

  String _truncate(String text, [int maxLength = 5000]) {
    if (text.length <= maxLength) {
      return text;
    }

    return '${text.substring(0, maxLength)}...';
  }
}
