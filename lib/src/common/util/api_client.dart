import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http_package;
import 'package:l/l.dart';

const successStatusCodes = <int>[200, 201, 202, 203, 204];

/// A function that takes a [http_package.BaseRequest] and returns a [http_package.StreamedResponse].
/// The [context] parameter is a map that can be used to store datasources that should be available to all middleware.
typedef ApiClientHandler =
    Future<APIClientResponse> Function(
      APIClientRequest request,
      Map<String, Object?> context,
      void Function(String message)? onServerErrorMessage,
    );

/// A function that takes a [ApiClientHandler] and returns a [ApiClientHandler].
typedef ApiClientMiddleware = ApiClientHandler Function(ApiClientHandler innerHandler);

/// A wrapper for [ApiClientMiddleware] that allows for optional handlers.
extension type ApiClientMiddlewareWrapper._(ApiClientMiddleware _fn) {
  /// Creates a new [ApiClientMiddleware] from the given callbacks.
  factory ApiClientMiddlewareWrapper({
    Future<void> Function(
      APIClientRequest request,
      Map<String, Object?> context,
      void Function(String message)? onServerErrorMessage,
    )?
    onRequest,
    Future<void> Function(
      APIClientResponse response,
      Map<String, Object?> context,
      void Function(String message)? onServerErrorMessage,
    )?
    onResponse,
    Future<void> Function(
      Object error,
      StackTrace stackTrace,
      Map<String, Object?> context,
      void Function(String message)? onServerErrorMessage,
    )?
    onError,
  }) => ApiClientMiddlewareWrapper._(
    (innerHandler) => (request, context, onServerErrorMessage) async {
      await onRequest?.call(request, context, onServerErrorMessage);
      try {
        final response = await innerHandler(request, context, onServerErrorMessage);
        await onResponse?.call(response, context, onServerErrorMessage);
        return response;
      } on Object catch (error, stackTrace) {
        await onError?.call(error, stackTrace, context, onServerErrorMessage);
        rethrow;
      }
    },
  );

  /// Merges the given [middlewares] into a single [ApiClientMiddleware].
  factory ApiClientMiddlewareWrapper.merge(List<ApiClientMiddleware> middlewares) =>
      ApiClientMiddlewareWrapper._(
        middlewares.length == 1
            ? middlewares.single
            : (handler) =>
                  middlewares.reversed.fold(handler, (handler, middleware) => middleware(handler)),
      );

  /// Call the wrapped [ApiClientMiddleware] with the given [innerHandler].
  ApiClientHandler call(ApiClientHandler innerHandler) => _fn(innerHandler);
}

/// An HTTP request with a JSON-encoded body.
extension type APIClientRequest(http_package.BaseRequest _request)
    implements http_package.BaseRequest {}

/// An HTTP response with a JSON-encoded body.
final class APIClientResponse {
  /// Create a new HTTP response with a JSON-encoded body.
  APIClientResponse.json(
    this.body, {
    required this.statusCode,
    required this.headers,
    required this.contentLength,
    required this.persistentConnection,
    required this.request,
  });

  final int statusCode;

  final Map<String, String> headers;

  final int contentLength;

  final Map<String, Object?> body;

  final bool persistentConnection;

  final APIClientRequest request;

  bool get success => successStatusCodes.contains(statusCode);
}

/// {@template api_client}
/// An HTTP client that sends requests to a REST API.
/// {@endtemplate}
class ApiClient /* with http_package.BaseClient implements http_package.Client */ {
  ApiClient({
    required String baseUrl,
    http_package.Client? client,
    Iterable<ApiClientMiddleware>? middlewares,
  }) : _baseUrl = Uri.parse(
         baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
       ),
       assert(!baseUrl.endsWith('//'), 'Invalid base URL.') {
    // Create the HTTP client.
    final internalClient = client ?? http_package.Client();

    // Create the final middleware.
    final mw = ApiClientMiddlewareWrapper.merge([
      /* default middlewares before custom middlewares */
      ...?middlewares,
      /* default middlewares after custom middlewares */
    ]);

    // Create the handler.
    _handler = _createHandler(internalClient, mw.call);
  }

  final Uri _baseUrl;

  late final ApiClientHandler _handler;

  /// Merges the given [path] with the base URL.
  static Uri _mergePath(Uri base, String path) {
    if (path.startsWith('http')) return Uri.parse(path);
    var method = path;
    while (method.startsWith('/')) method = method.substring(1);
    return base.replace(path: '${base.path}/$method');
  }

  /// Sends a non-streaming [http_package.Request] and returns a non-streaming [http_package.Response].
  static Future<APIClientResponse> _sendUnstreamed({
    required ApiClientHandler handler,
    required String method,
    required Uri url,
    required Map<String, String?>? queryParameters,
    required Map<String, String>? headers,
    required Map<String, Object?>? body,
    required Map<String, Object?> context,
    void Function(String message)? onServerErrorMessage,
  }) {
    final finalUrl = queryParameters == null
        ? url
        : url.replace(queryParameters: {...url.queryParameters, ...queryParameters});

    final request = http_package.Request(method, finalUrl)..maxRedirects = 5;
    request.headers['Accept'] = 'application/json';
    if (headers != null) request.headers.addAll(headers);
    if (body != null) {
      final bytes = const JsonEncoder().fuse(const Utf8Encoder()).convert(body);
      final contentLength = bytes.length;
      request.headers
        ..['Content-Type'] = 'application/json; charset=UTF-8'
        ..['Content-Length'] = contentLength.toString();
      request
              // ..contentLength = contentLength
              .bodyBytes =
          bytes;
    }
    return handler(APIClientRequest(request), context, onServerErrorMessage);
  }

  /// Sends a GET request to the given [path].
  Future<APIClientResponse> get(
    String path, {
    Map<String, String?>? queryParameters,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 90),
    void Function(String message)? onServerErrorMessage,
  }) =>
      _sendUnstreamed(
        handler: _handler,
        method: 'GET',
        url: _mergePath(_baseUrl, path),
        queryParameters: queryParameters,
        headers: headers,
        body: null,
        context: <String, Object?>{},
        onServerErrorMessage: onServerErrorMessage,
      ).timeout(
        timeout,
        onTimeout: () => throw APIClientException$Network(
          code: 'timeout_error',
          message: 'Request timed out after ${timeout.inSeconds} seconds.',
          statusCode: 0,
          error: TimeoutException('Request timeout'),
          data: null,
        ),
      );

  /// Sends a POST request to the given [path].
  Future<APIClientResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, String?>? queryParameters,
    Map<String, Object?>? body,
    Duration timeout = const Duration(seconds: 90),
    void Function(String message)? onServerErrorMessage,
  }) =>
      _sendUnstreamed(
        handler: _handler,
        method: 'POST',
        url: _mergePath(_baseUrl, path),
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        context: <String, Object?>{},
        onServerErrorMessage: onServerErrorMessage,
      ).timeout(
        timeout,
        onTimeout: () => throw APIClientException$Network(
          code: 'timeout_error',
          message: 'Request timed out after ${timeout.inSeconds} seconds.',
          statusCode: 0,
          error: TimeoutException('Request timeout'),
          data: null,
        ),
      );

  Future<APIClientResponse> patch(
    String path, {
    Map<String, String>? headers,
    Map<String, String?>? queryParameters,
    Map<String, Object?>? body,
    Duration timeout = const Duration(seconds: 90),
    void Function(String message)? onServerErrorMessage,
  }) =>
      _sendUnstreamed(
        handler: _handler,
        method: 'PATCH',
        url: _mergePath(_baseUrl, path),
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        context: <String, Object?>{},
        onServerErrorMessage: onServerErrorMessage,
      ).timeout(
        timeout,
        onTimeout: () => throw APIClientException$Network(
          code: 'timeout_error',
          message: 'Request timed out after ${timeout.inSeconds} seconds.',
          statusCode: 0,
          error: TimeoutException('Request timeout'),
          data: null,
        ),
      );

  Future<APIClientResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, String?>? queryParameters,
    Map<String, Object?>? body,
    Duration timeout = const Duration(seconds: 90),
    void Function(String message)? onServerErrorMessage,
  }) =>
      _sendUnstreamed(
        handler: _handler,
        method: 'PUT',
        url: _mergePath(_baseUrl, path),
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        context: <String, Object?>{},
        onServerErrorMessage: onServerErrorMessage,
      ).timeout(
        timeout,
        onTimeout: () => throw APIClientException$Network(
          code: 'timeout_error',
          message: 'Request timed out after ${timeout.inSeconds} seconds.',
          statusCode: 0,
          error: TimeoutException('Request timeout'),
          data: null,
        ),
      );

  Future<APIClientResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, String?>? queryParameters,
    Map<String, Object?>? body,
    Duration timeout = const Duration(seconds: 90),
    void Function(String message)? onServerErrorMessage,
  }) =>
      _sendUnstreamed(
        handler: _handler,
        method: 'DELETE',
        url: _mergePath(_baseUrl, path),
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        context: <String, Object?>{},
        onServerErrorMessage: onServerErrorMessage,
      ).timeout(
        timeout,
        onTimeout: () => throw APIClientException$Network(
          code: 'timeout_error',
          message: 'Request timed out after ${timeout.inSeconds} seconds.',
          statusCode: 0,
          error: TimeoutException('Request timeout'),
          data: null,
        ),
      );
}

/// Creates a new [ApiClientHandler] from the given [internalClient] and [middleware].
ApiClientHandler _createHandler(
  http_package.Client internalClient,
  ApiClientMiddleware middleware,
) {
  // Check if the completer is completed and throw an error if it is.
  void throwError(Completer<APIClientResponse> completer, Object error, StackTrace stackTrace) {
    if (completer.isCompleted)
      return;
    else if (error is APIClientException)
      completer.completeError(error, stackTrace);
    else
      completer.completeError(
        APIClientException$Client(
          code: 'unknown_error',
          message: 'Unknown error.',
          statusCode: 0,
          error: error,
          data: null,
        ),
        stackTrace,
      );
  }

  // JSON decoder.
  final jsonDecoder = const Utf8Decoder()
      .fuse(const JsonDecoder())
      .cast<Object?, Map<String, Object?>>();

  // HTTP handler.
  Future<APIClientResponse> httpHandler(
    APIClientRequest request,
    Map<String, Object?> context,
    void Function(String message)? onServerErrorMessage,
  ) {
    final completer = Completer<APIClientResponse>();
    // Handle top level errors.
    runZonedGuarded<void>(
      () async {
        assert(request.url.scheme.startsWith('http'), 'Invalid URL: ${request.url}');

        // Send a base request.
        final http_package.StreamedResponse streamedResponse;
        try {
          streamedResponse = await internalClient.send(request._request);
        } on Object catch (error, stackTrace) {
          onServerErrorMessage?.call('Network: Failed to send request due to a network error.');
          throwError(
            completer,
            APIClientException$Network(
              code: 'network_error',
              message: 'Failed to send request due to a network error.',
              statusCode: 0,
              error: error,
              data: null,
            ),
            stackTrace,
          );
          return;
        }

        // Check response.
        int statusCode;
        try {
          statusCode = streamedResponse.statusCode;
          switch (statusCode) {
            case > 499:
              onServerErrorMessage?.call('>=500: Internal server error');
              throw APIClientException$Network(
                code: 'internal_server_error',
                message: 'Internal server error.',
                statusCode: statusCode,
                error: null,
                data: null,
              );
            case 401 || 403:
              onServerErrorMessage?.call('401 | 403: User is not authorized');
              throw APIClientException$Authorization(
                code: 'unauthorized_error',
                message: 'User is not authorized.',
                statusCode: statusCode,
                error: null,
                data: null,
              );
            case > 399:
              var body = <String, Object?>{};
              try {
                final bytes = await streamedResponse.stream.toBytes();
                body = bytes.isEmpty ? <String, Object?>{} : jsonDecoder.convert(bytes);
              } on Object catch (error, stackTrace) {
                throwError(completer, error, stackTrace);
              }
              l
                ..e('---Incorrect server error')
                ..e('---Server statusCode: ${streamedResponse.statusCode}')
                ..e('---Reason: ${streamedResponse.reasonPhrase}')
                ..e('---Body: $body');

              if (body case {
                'error_data': Map<String, Object?> errorData,
                'message': String? message,
              }) {
                if (errorData case {'items': List<Object?> items, 'key': 'not_enough_qty'}) {
                  throw APIServerNotEnoughQtyException(
                    code: 'not_enough_qty',
                    message: message ?? 'Something went wrong: $body',
                    statusCode: statusCode,
                    data: items.whereType<String>().toList(),
                  );
                }
              }
              onServerErrorMessage?.call('>=400: Something went wrong with the client: $body');
              throw APIClientException$400(
                code: 'Client exception',
                message: 'Something went wrong with the client: $body',
                statusCode: statusCode,
                error: body,
                data: null,
              );
            case > 299:
              var body = <String, Object?>{};
              try {
                final bytes = await streamedResponse.stream.toBytes();
                body = bytes.isEmpty ? <String, Object?>{} : jsonDecoder.convert(bytes);
              } on Object catch (error, stackTrace) {
                throwError(completer, error, stackTrace);
              }
              l
                ..e('---Incorrect server error')
                ..e('---Server statusCode: ${streamedResponse.statusCode}')
                ..e('---Reason: ${streamedResponse.reasonPhrase}')
                ..e('---Body: $body');
              onServerErrorMessage?.call('>=300: Server was redirected: $body');
              throw APIClientException$300(
                code: 'Redirection exception',
                message: 'Server was redirected: $body',
                statusCode: statusCode,
                error: body,
                data: null,
              );
            default:
              break;
          }
        } on Object catch (error, stackTrace) {
          throwError(completer, error, stackTrace);
          return;
        }

        // Read the response stream.
        int contentLength;
        Uint8List bytes;
        try {
          contentLength = streamedResponse.contentLength ?? 0;

          // Always try to read the stream, regardless of contentLength
          // The server might not provide Content-Length header
          bytes = await streamedResponse.stream.toBytes();

          // If we got bytes but contentLength was 0, update it
          if (contentLength == 0 && bytes.isNotEmpty) {
            contentLength = bytes.length;
          }
        } on Object catch (error, stackTrace) {
          throwError(
            completer,
            APIClientException$Network(
              code: 'body_stream_error',
              message: 'Failed to read response stream.',
              statusCode: streamedResponse.statusCode,
              error: error,
              data: null,
            ),
            stackTrace,
          );
          return;
        }

        // Decode the response.
        APIClientResponse response;
        try {
          // Only check content-type if we have actual content
          if (bytes.isNotEmpty) {
            final contentType = streamedResponse.headers['content-type']?.toLowerCase() ?? '';
            if (!contentType.contains('application/json')) {
              // Log the actual content for debugging
              l
                ..w('Received non-JSON response: $contentType')
                ..w('Body: ${utf8.decode(bytes)}');
              throwError(
                completer,
                APIClientException$Client(
                  code: 'invalid_content_type_error',
                  message: 'Response content type is not application/json.',
                  statusCode: statusCode,
                  error: null,
                  data: bytes,
                ),
                StackTrace.current,
              );
              return;
            }
          }

          final body = bytes.isEmpty ? <String, Object?>{} : jsonDecoder.convert(bytes);
          response = APIClientResponse.json(
            body,
            statusCode: streamedResponse.statusCode,
            headers: streamedResponse.headers,
            contentLength: contentLength,
            persistentConnection: streamedResponse.persistentConnection,
            request: request,
          );
        } on Object catch (error, stackTrace) {
          // Log the actual bytes for debugging
          l.e('Failed to decode response: $error');
          try {
            l.e('Response body: ${utf8.decode(bytes)}');
          } on Object catch (_) {
            l.e('Could not decode bytes as UTF-8');
          }

          throwError(
            completer,
            APIClientException$Client(
              code: 'decoding_error',
              message: 'Failed to decode response.',
              statusCode: streamedResponse.statusCode,
              error: error,
              data: bytes,
            ),
            stackTrace,
          );
          return;
        }

        // Complete the completer.
        if (!completer.isCompleted) completer.complete(response);
      },
      (error, stackTrace) {
        throwError(completer, error, stackTrace);
      },
    );
    return completer.future;
  }

  return middleware(httpHandler);
}

// --- Errors --- //

@immutable
sealed class APIClientException implements Exception {
  const APIClientException();

  /// HTTP status code.
  /// If the request was not sent, this will be 0.
  abstract final int statusCode;

  /// Error code.
  abstract final String code;

  /// Error message.
  abstract final String message;

  /// The source error object.
  abstract final Object? error;

  /// Additional datasources.
  abstract final Object? data;

  @override
  String toString() => message;
}

/// Client exception.
final class APIClientException$Client extends APIClientException {
  const APIClientException$Client({
    required this.code,
    required this.message,
    required this.statusCode,
    this.error,
    this.data,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final int statusCode;

  @override
  final Object? error;

  @override
  final Object? data;
}

/// Network exception.
final class APIClientException$Network extends APIClientException {
  const APIClientException$Network({
    required this.code,
    required this.message,
    required this.statusCode,
    this.error,
    this.data,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final int statusCode;

  @override
  final Object? error;

  @override
  final Object? data;
}

/// Authorization exception.
final class APIClientException$Authorization extends APIClientException {
  const APIClientException$Authorization({
    required this.code,
    required this.message,
    required this.statusCode,
    this.error,
    this.data,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final int statusCode;

  @override
  final Object? error;

  @override
  final Object? data;
}

final class APIClientException$400 extends APIClientException {
  const APIClientException$400({
    required this.code,
    required this.message,
    required this.statusCode,
    this.error,
    this.data,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final int statusCode;

  @override
  final Object? error;

  @override
  final Object? data;
}

final class APIClientException$300 extends APIClientException {
  const APIClientException$300({
    required this.code,
    required this.message,
    required this.statusCode,
    this.error,
    this.data,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final int statusCode;

  @override
  final Object? error;

  @override
  final Object? data;
}

final class APIServerNotEnoughQtyException extends APIClientException {
  const APIServerNotEnoughQtyException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.error,
    this.data,
  });

  @override
  final String code;

  @override
  final String message;

  @override
  final int statusCode;

  @override
  final Object? error;

  @override
  final List<String>? data;
}
