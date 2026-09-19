/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:convert';
import 'package:guardian/core/utils/logger.dart';

/// A utility class for network operations
class NetworkUtils {
  /// Checks if an error is a network-related error
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet');
  }

  /// Formats a URL by ensuring it has the correct scheme and path
  static String formatUrl(String baseUrl, String path) {
    // Add https:// if not present
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'https://$baseUrl';
    }

    // Remove trailing slash from baseUrl
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // Add leading slash to path if not present
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    return baseUrl + path;
  }

  /// Gets a user-friendly error message based on the error
  static String getErrorMessage(dynamic error) {
    if (error is int) {
      // HTTP status code
      switch (error) {
        case 400:
          return 'Bad request. Please check your input.';
        case 401:
          return 'Unauthorized. Please log in again.';
        case 403:
          return 'Forbidden. You do not have permission to access this resource.';
        case 404:
          return 'Not found. The requested resource does not exist.';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Server error. Please try again later.';
        default:
          return 'An error occurred. Please try again.';
      }
    } else {
      // Exception or other error
      final errorString = error.toString().toLowerCase();

      if (errorString.contains('failed host lookup')) {
        return 'No internet connection';
      } else if (errorString.contains('connection refused')) {
        return 'Server is not responding';
      } else if (errorString.contains('connection timed out')) {
        return 'Request timed out';
      } else {
        return 'An error occurred';
      }
    }
  }

  /// Parses a JSON string into a Map
  static dynamic parseJson(String jsonString) {
    if (jsonString.isEmpty) return null;

    try {
      return json.decode(jsonString);
    } catch (e) {
      Logger.error('Error parsing JSON', e);
      return null;
    }
  }

  /// Encodes query parameters for a URL
  static String encodeQueryParameters(Map<String, dynamic> params) {
    if (params.isEmpty) return '';

    return params.entries
        .where((entry) => entry.value != null)
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
  }

  /// Builds a URL with base URL, path, and query parameters
  static String buildUrl(String baseUrl, String path,
      [Map<String, dynamic>? queryParams]) {
    // Format the base URL and path
    final formattedUrl = formatUrl(baseUrl, path);

    // Add query parameters if provided
    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = encodeQueryParameters(queryParams);
      return '$formattedUrl?$queryString';
    }

    return formattedUrl;
  }

  /// Checks if an HTTP status code indicates success
  static bool isSuccessStatusCode(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Extracts the domain from a URL
  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      Logger.error('Error extracting domain from URL', e);
      return url;
    }
  }

  /// Checks if a URL is valid
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme.isNotEmpty && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Converts a Map to a JSON string
  static String toJson(Map<String, dynamic> data) {
    try {
      return json.encode(data);
    } catch (e) {
      Logger.error('Error converting Map to JSON', e);
      return '{}';
    }
  }

  /// Gets the content type from a file extension
  static String getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      default:
        return 'application/octet-stream';
    }
  }
}
