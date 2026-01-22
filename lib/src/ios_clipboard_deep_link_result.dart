/*
/// Represents a deep link detected from the iOS clipboard.
///
/// Example clipboard value:
///   "https://example.com/?referrer=home&uid=1000000"
///   "https://m.example.com/?referrer=home&uid=1000000"
///
/// Usage:
///   result.fullDeepLink           -> full string from clipboard
///   result.fullReferralDeepLinkPath (alias)
///   result.queryParameters        -> { "referrer": "home", "uid": "1000000" }
///   result.getParam("referrer")   -> "home"
*/

import 'package:smler_deferred_link/src/helpers.dart';

class IosClipboardDeepLinkResult {
  IosClipboardDeepLinkResult({required this.fullDeepLink, required this.uri});

  /// The full deep link string exactly as taken from the clipboard.
  final String fullDeepLink;

  /// Parsed URI form of [fullDeepLink].
  final Uri uri;

  /// Alias: full referral deep link path.
  String get fullReferralDeepLinkPath => fullDeepLink;

  /// Parsed query parameters after the `?`.
  ///
  /// Example:
  ///   fullDeepLink = "https://example.com?referrer=home&uid=10"
  ///   => { "referrer": "home", "uid": "10" }
  Map<String, String> get queryParameters => uri.queryParameters;

  /// Convenience helper to access a specific query parameter.
  ///
  /// Example:
  ///   getParam("referrer") -> "home"
  ///   getParam("uid")     -> "10"
  String? getParam(String key) => queryParameters[key];

  /// Extracts shortCode and optional dltHeader from the deep link URL.
  ///
  /// Supports two formats:
  /// - `https://domain.com/[dltHeader]/[shortCode]` - with optional dltHeader
  /// - `https://domain.com/[shortCode]` - shortCode only
  ///
  /// Returns a Map with keys 'shortCode' and 'dltHeader'.
  /// If dltHeader is not present, it will be null.
  /// If the URL doesn't match the format, returns empty strings/null.
  ///
  /// Example:
  /// ```dart
  /// final result = iosResult.extractShortCodeAndDltHeader();
  /// final shortCode = result['shortCode']; // e.g., "abc123"
  /// final dltHeader = result['dltHeader']; // e.g., "promo" or null
  /// ```
  Map<String, String?> extractShortCodeAndDltHeader() {
    // Get path segments (excluding empty segments)
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) {
      return {'shortCode': '', 'dltHeader': null};
    }

    // If we have 2 segments: [dltHeader, shortCode]
    // If we have 1 segment: [shortCode]
    if (segments.length >= 2) {
      return {
        'dltHeader': segments[0],
        'shortCode': segments[1],
      };
    } else {
      return {
        'dltHeader': null,
        'shortCode': segments[0],
      };
    }
  }

  /// Tracks a click by sending data to the Smler API.
  ///
  /// Automatically extracts clickId from query parameters and shortCode/dltHeader from
  /// the deep link URL path, then sends them to the tracking API.
  ///
  /// The clickId is extracted from the 'clickId' query parameter in the deep link URL.
  /// If clickId doesn't exist or is empty, returns null without making an API call.
  ///
  /// Returns a Map with the API response data, error information, or null if no clickId.
  ///
  /// Example:
  /// ```dart
  /// final iosResult = await SmlerDeferredLink.getInstallReferrerIos(
  ///   deepLinks: ['https://yourdomain.com'],
  /// );
  /// if (iosResult != null) {
  ///   final response = await iosResult.trackClick();
  ///   if (response != null) {
  ///     print('Tracking response: $response');
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>?> trackClick() async {
    final clickId = getParam('clickId');
    if (clickId == null || clickId.isEmpty) {
      return null;
    }
    final pathParams = extractShortCodeAndDltHeader();
    final domain = uri.host;
    return HelperReferrer.fetchTrackingData(clickId, pathParams, domain);
  }

  @override
  String toString() =>
      'IosClipboardDeepLinkResult(fullDeepLink: $fullDeepLink, queryParameters: $queryParameters)';
}
