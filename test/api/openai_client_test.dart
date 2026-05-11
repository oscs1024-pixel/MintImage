import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_image_flutter/core/api/openai_client.dart';

void main() {
  test('extractErrorMessage includes HTTP status code when available', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/images/generations'),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/images/generations'),
        statusCode: 504,
        data: {
          'error': {'message': 'Gateway timeout'},
        },
      ),
    );

    expect(OpenAiClient.extractErrorMessage(error), 'HTTP 504：Gateway timeout');
  });
}
