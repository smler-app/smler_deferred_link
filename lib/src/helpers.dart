import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class HelperReferrer {
  /// Returns true if [clipboard] deep link matches [pattern],
  /// supporting:
  ///   - http / https / no scheme
  ///   - www.
  ///   - any subdomain of the pattern's base domain
  ///   - wildcard host:      "*.example.com"
  ///   - wildcard path:      "example.com/*", "example.com/profile/*"
  ///
  /// Examples:
  ///   clipboard: "https://sub.example.com/profile?x=1"
  ///   pattern:   "https://example.com/profile"
  ///   => true (same base domain, path prefix)
  ///
  ///   clipboard: "https://m.example.com/offer?id=1"
  ///   pattern:   "example.com"
  ///   => true (same base domain, any path)
  ///
  ///   clipboard: "https://foo.example.com/profile/settings"
  ///   pattern:   "*.example.com/profile/*"
  ///   => true (wildcard subdomain + wildcard path)
  static bool matchesDeepLinkPattern({
    required String clipboard,
    required String pattern,
  }) {
    final trimmedPattern = pattern.trim();

    // Global wildcard: "*" → match anything that can be parsed as a URL.
    if (trimmedPattern == '*') {
      return parseToUri(clipboard) != null;
    }

    // Quick normalization for raw string compare
    final normalizedClipboard = normalizeUrlLikeString(clipboard);
    final normalizedPattern = normalizeUrlLikeString(trimmedPattern);

    // Simple direct/prefix check (keeps your original fast path).
    if (normalizedClipboard == normalizedPattern ||
        normalizedClipboard.startsWith(normalizedPattern)) {
      return true;
    }

    // Try URI-based matching for domain and path
    final clipboardUri = parseToUri(clipboard);
    final patternUri = parseToUri(trimmedPattern);

    if (clipboardUri == null || patternUri == null) {
      return false;
    }

    String stripWww(String host) =>
        host.toLowerCase().startsWith('www.') ? host.substring(4) : host;

    final cbHostBase = stripWww(clipboardUri.host);
    final ptHostBase = stripWww(patternUri.host);

    if (cbHostBase.isEmpty || ptHostBase.isEmpty) {
      return false;
    }

    // -----------------------------
    // Host match rules (with wildcard)
    // -----------------------------
    bool hostMatches;

    if (ptHostBase.startsWith('*.')) {
      // Pattern like "*.example.com" → match any subdomain + root.
      final base = ptHostBase.substring(2); // remove "*."
      hostMatches = cbHostBase == base || cbHostBase.endsWith('.$base');
    } else {
      // Original behavior:
      //  - same base host
      //  - OR clipboard host is a subdomain of pattern base host
      hostMatches =
          cbHostBase == ptHostBase || cbHostBase.endsWith('.$ptHostBase');
    }

    if (!hostMatches) {
      return false;
    }

    // -----------------------------
    // Path rule (with wildcard)
    // -----------------------------
    final clipboardPath = clipboardUri.path.isEmpty ? '/' : clipboardUri.path;
    final patternPathRaw = patternUri.path;

    // If pattern has no specific path ("/" or ""), accept any clipboard path
    if (patternPathRaw.isEmpty || patternPathRaw == '/') {
      return true; // any path is OK as long as host matched
    }

    // Wildcard entire path: "example.com/*" or "https://example.com/*"
    if (patternPathRaw == '/*' || patternPathRaw == '*') {
      return true;
    }

    // Path wildcard suffix: "/profile/*" → match /profile and anything under it
    if (patternPathRaw.endsWith('/*')) {
      final basePath = patternPathRaw.substring(
          0, patternPathRaw.length - 1); // keep trailing "/"
      return clipboardPath.startsWith(basePath);
    }

    // Default: path prefix match (existing behaviour)
    return clipboardPath.startsWith(patternPathRaw);
  }

  /// Normalize URL-like strings so that:
  ///   "https://example.com/profile?ref=abc"
  ///   "http://example.com/profile?ref=abc"
  ///   "example.com/profile?ref=abc"
  ///
  /// all become:
  ///   "example.com/profile?ref=abc"
  static String normalizeUrlLikeString(String value) {
    var v = value.trim();

    if (v.toLowerCase().startsWith('https://')) {
      v = v.substring('https://'.length);
    } else if (v.toLowerCase().startsWith('http://')) {
      v = v.substring('http://'.length);
    }

    return v;
  }

  /// Try to parse a URL-like string as a [Uri].
  ///
  /// If no scheme is present, assume "https://".
  static Uri? parseToUri(String value) {
    final trimmed = value.trim();

    Uri? tryParse(String candidate) {
      try {
        final uri = Uri.tryParse(candidate);
        if (uri == null || (uri.host.isEmpty && !uri.hasAuthority)) {
          return null;
        }
        return uri;
      } catch (_) {
        return null;
      }
    }

    // If it already has http/https scheme, try directly.
    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://')) {
      return tryParse(trimmed);
    }

    // Otherwise, assume https://
    return tryParse('https://$trimmed');
  }

  /// Fetches tracking data from the Smler API.
  ///
  /// [clickId] - The click ID from query parameters
  /// [pathParams] - Map containing 'shortCode' and optional 'dltHeader'
  /// [domain] - The domain name from the referrer URL
  ///
  /// Returns a Map with the API response data or error information.
  ///
  /// Example:
  /// ```dart
  /// final pathParams = referrerInfo.extractShortCodeAndDltHeader();
  /// final response = await HelperReferrer.fetchTrackingData(
  ///   'click123',
  ///   pathParams,
  ///   'example.com',
  /// );
  /// ```
  static Future<Map<String, dynamic>> fetchTrackingData(
    String clickId,
    Map<String, String?> pathParams,
    String? domain,
  ) async {
    try {
      final url = 'https://smler.in/api/v2/track/$clickId';

      // Prepare request body with optional parameters
      final Map<String, dynamic> requestBody = {};

      if (pathParams['shortCode'] != null &&
          pathParams['shortCode']!.isNotEmpty) {
        requestBody['shortCode'] = pathParams['shortCode']!;
      }

      if (pathParams['dltHeader'] != null &&
          pathParams['dltHeader']!.isNotEmpty) {
        requestBody['dltHeader'] = pathParams['dltHeader'];
      }

      if (domain != null && domain.isNotEmpty) {
        requestBody['domain'] = domain;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'error': 'HTTP ${response.statusCode}',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'error': 'Exception',
        'message': e.toString(),
      };
    }
  }

  /// Performs probabilistic matching to link install events to clicks.
  ///
  /// [domain] - Domain name (required)
  /// [clickId] - Optional click ID for additional matching
  ///
  /// Device and OS information are automatically extracted from the current platform.
  ///
  /// Returns a Map with match results including:
  /// - matched: bool indicating if a match was found
  /// - score: confidence score of the match
  /// - matchedAttributes: attributes that matched
  /// - clickDetails: details of the matched click
  /// - shortUrl: complete short URL object with metadata
  /// - fingerprint: device fingerprint data
  /// - domain: extracted domain from shortUrl
  /// - pathParams: map containing shortCode, dltHeader, and domain
  ///
  /// Example:
  /// ```dart
  /// final result = await HelperReferrer.getProbabilisticMatch(
  ///   domain: 'example.com',
  /// );
  /// if (result['matched'] == true) {
  ///   print('Match score: ${result['score']}');
  ///   print('Short code: ${result['pathParams']['shortCode']}');
  /// }
  /// ```
  static Future<Map<String, dynamic>> getProbabilisticMatch({
    required String domain,
    String? clickId,
  }) async {
    try {
      // Validate required parameter
      if (domain.trim().isEmpty) {
        return {
          'error': 'Validation',
          'message': 'Domain is required',
        };
      }

      // Automatically extract device and OS information
      final deviceInfoPlugin = DeviceInfoPlugin();
      String device = 'Unknown';
      String os = 'Unknown';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        device = '${androidInfo.manufacturer} ${androidInfo.model}';
        os = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        device = iosInfo.utsname.machine;
        os = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfoPlugin.macOsInfo;
        device = macInfo.model;
        os = 'macOS ${macInfo.osRelease}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        device = windowsInfo.computerName;
        os = 'Windows';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfoPlugin.linuxInfo;
        device = linuxInfo.name;
        os = 'Linux';
      }

      final url = 'https://smler.in/api/v2/track/probablistic';

      final Map<String, dynamic> requestBody = {
        'device': device,
        'os': os,
        'domain': domain,
      };

      if (clickId != null && clickId.isNotEmpty) {
        requestBody['clickId'] = clickId;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract shortUrl data if available
        final shortUrl = data['shortUrl'] as Map<String, dynamic>?;

        // Build formatted response
        final formattedResponse = <String, dynamic>{
          'matched': data['matched'] ?? false,
          'score': (data['score'] as num?)?.toDouble(),
          'matchedAttributes': data['matchedAttributes'],
          'clickDetails': data['clickDetails'],
          'shortUrl': shortUrl,
          'fingerprint': data['fingerprint'],
        };

        // Add domain and pathParams if shortUrl exists
        if (shortUrl != null) {
          formattedResponse['domain'] = shortUrl['domain'];
          formattedResponse['originalUrl'] = shortUrl['originalUrl'];
          formattedResponse['pathParams'] = {
            'shortCode': shortUrl['shortCode'],
            'dltHeader': shortUrl['dltHeader'],
            'domain': shortUrl['domain'],
          };
        }

        return formattedResponse;
      } else {
        return {
          'error': 'HTTP ${response.statusCode}',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'error': 'Exception',
        'message': e.toString(),
      };
    }
  }

  /// Parses an opened deep link to extract [dltHeader] and [shortCode].
  /// Refers to the logic in [extractShortCodeAndDltHeader].
  ///
  /// Hits the endpoint:
  /// `curl --location 'https://smler.in/api/v1/short?short=ZoxHzANoVQ&dltHeader=optional-dlt-header&domain=mydomain.com'`
  ///
  /// Reference: https://documenter.getpostman.com/view/21304751/2sAY517zaC#12287d05-2d56-4e56-9e43-305da8ac32c3
  static Future<Map<String, dynamic>> resolveDeepLinkData(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return {'error': 'Invalid URL'};
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      String shortCode = '';
      String? dltHeader;

      if (segments.length >= 2) {
        dltHeader = segments[0];
        shortCode = segments[1];
      } else if (segments.isNotEmpty) {
        shortCode = segments[0];
      } else {
        return {'error': 'No short code found in URL'};
      }

      final domain = uri.host;
      final queryParams = {
        'short': shortCode,
        if (dltHeader != null) 'dltHeader': dltHeader,
        'domain': domain,
      };

      final apiUri = Uri.https('smler.in', '/api/v1/short', queryParams);

      final response = await http.get(apiUri);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'error': 'HTTP ${response.statusCode}',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'error': 'Exception',
        'message': e.toString(),
      };
    }
  }

  /// Triggers a webhook for the given [shortCode], [dltHeader], and [domain].
  ///
  /// Equivalent to:
  /// ```
  /// curl --location --request POST
  ///   'https://smler.in/api/v1/webhook?dltHeader=BKMTCH&shortCode=Ffo6TOPIkd&domain=smler.in'
  /// ```
  ///
  /// Call this after resolving a deep link to notify your backend that the
  /// link was opened.
  ///
  /// Returns the parsed response body on success, or a map with an 'error'
  /// key on failure.
  static Future<Map<String, dynamic>> triggerWebhook({
    required String shortCode,
    required String domain,
    String? dltHeader,
  }) async {
    try {
      final queryParams = <String, String>{
        'shortCode': shortCode,
        'domain': domain,
        if (dltHeader != null && dltHeader.isNotEmpty) 'dltHeader': dltHeader,
      };

      final uri = Uri.https('smler.in', '/api/v1/webhook', queryParams);

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return {'success': true};
        return json.decode(body) as Map<String, dynamic>;
      } else {
        return {
          'error': 'HTTP ${response.statusCode}',
          'message': response.body,
        };
      }
    } catch (e) {
      return {
        'error': 'Exception',
        'message': e.toString(),
      };
    }
  }
}