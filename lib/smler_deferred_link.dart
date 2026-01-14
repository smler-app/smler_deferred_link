library;

// Package : smler_deferred_link
// Author : Bokimo Technologies LLP
// Published Date : 14/Jan/2026

/*
  smler_deferred_link provides a reliable, SDK-free solution for deferred deep linking on both Android and iOS.
  On Android, it uses the official Google Play Install Referrer API to retrieve referrer parameters after installation.
  On iOS, it implements a robust clipboard deep link fallback that works even when iCloud Private Relay prevents traditional attribution.
  It supports multiple domains, subdomains, www/non-www, and full query-parameter parsing.
  Ideal for apps that need simple, privacy-friendly deferred deep linking without heavy third-party SDKs.
 */

export 'src/ios_clipboard_deep_link_result.dart';
export 'src/smler_deferred_link.dart';
