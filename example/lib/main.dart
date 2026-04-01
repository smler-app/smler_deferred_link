import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smler_deferred_link/smler_deferred_link.dart';
import 'package:smler_deferred_link/src/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint(
      '🚀 Stack Deferred Link example starting on platform: ${Platform.operatingSystem}');
  runApp(const MyApp());
}

/// ---------------------------------------------------------------------------
/// App Root
/// ---------------------------------------------------------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _demoDomain = 'go.singh3y.dev';

  // Android data
  ReferrerInfo? _referrerInfo;
  Map<String, String> _parsedParams = {};

  // iOS data
  IosClipboardDeepLinkResult? _iosDeepLink;
  Map<String, String> _iosParams = {};

  // Probabilistic match data (iOS only)
  Map<String, dynamic>? _probabilisticMatchResult;
  bool _usedProbabilisticFallback = false;

  // Deep link resolution data
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _deepLinkSub;
  String? _latestReceivedDeepLink;
  Map<String, dynamic>? _resolvedDeepLinkData;
  bool _isResolvingDeepLink = false;
  String? _resolveDeepLinkError;

  String? _errorMessage;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
    unawaited(_loadInitialData());
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<dynamic> _asDynamicList(dynamic value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value;
    }
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value == true || entry.value == 1)
          .map((entry) => entry.key)
          .toList();
    }
    return [value];
  }

  void _setupDeepLinkListener() {
    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          unawaited(_resolveAndShowDeepLink(uri.toString()));
        }
      },
      onError: (Object err) {
        debugPrint('Error receiving deep link: $err');
        if (!mounted) {
          return;
        }
        setState(() {
          _resolveDeepLinkError = err.toString();
          _isResolvingDeepLink = false;
        });
      },
    );
  }

  Future<void> _resolveAndShowDeepLink(String deepLink) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _latestReceivedDeepLink = deepLink;
      _resolvedDeepLinkData = null;
      _resolveDeepLinkError = null;
      _isResolvingDeepLink = true;
    });

    try {
      final resolvedData = await SmlerDeferredLink.resolveDeepLink(deepLink);
      if (!mounted) {
        return;
      }

      setState(() {
        _resolvedDeepLinkData = resolvedData;
        _resolveDeepLinkError = resolvedData['error']?.toString();
        _isResolvingDeepLink = false;
      });

      debugPrint('Resolved deep link data: $resolvedData');

      // Trigger a webhook to notify the backend that this deep link was opened.
      final shortCode = resolvedData['shortCode'] as String?;
      final domain = resolvedData['domain'] as String?;
      final dltHeader = resolvedData['dltHeader'] as String?;
      if (shortCode != null && domain != null) {
        final webhookResult = await HelperReferrer.triggerWebhook(
          shortCode: shortCode,
          domain: domain,
          dltHeader: dltHeader,
        );
        debugPrint('Webhook result: $webhookResult');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint('Error resolving deep link: $e');
      setState(() {
        _resolveDeepLinkError = e.toString();
        _isResolvingDeepLink = false;
      });
    }
  }

  String _formatResolvedData(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isInitialLoading = true;
      });
    }

    try {
      // Deferred attribution (install referrer / clipboard / probabilistic)
      // runs ONLY on the very first install. On subsequent app opens only
      // the live deep-link listener (set up in initState) is active.
      final prefs = await SharedPreferences.getInstance();
      final isFirstInstall = prefs.getBool('smler_first_install') ?? true;

      if (isFirstInstall) {
        debugPrint(
            '🆕 First install detected – running deferred attribution flow.');
        await _runDeferredAttributionFlow();
        await prefs.setBool('smler_first_install', false);
      } else {
        debugPrint('🔁 Subsequent launch – skipping deferred attribution.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DEFERRED ATTRIBUTION FLOW (first install only)
  //
  // Determines how the user arrived at the app:
  //   Android → Google Play Install Referrer
  //   iOS     → Clipboard deep-link check, with probabilistic fallback
  // ---------------------------------------------------------------------------

  Future<void> _runDeferredAttributionFlow() async {
    try {
      if (Platform.isAndroid) {
        await _runAndroidDeferredAttribution();
      } else if (Platform.isIOS) {
        await _runIosDeferredAttribution();
      } else {
        setState(() => _errorMessage = 'Platform not supported.');
      }
    } catch (e) {
      debugPrint('⚠ Error in deferred attribution flow: $e');
      setState(() => _errorMessage = e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // ANDROID – Google Play Install Referrer
  //
  // Reads the referrer string set when the user tapped your Play Store link.
  // After reading the referrer, it runs a probabilistic match as a supplement
  // (useful when the referrer string is empty or generic).
  // ---------------------------------------------------------------------------

  Future<void> _runAndroidDeferredAttribution() async {
    try {
      debugPrint('📥 [Android] Reading Google Play Install Referrer…');

      final info = await SmlerDeferredLink.getInstallReferrerAndroid();

      debugPrint('✅ Install Referrer: ${info.installReferrer}');
      debugPrint('   Parsed params: ${info.asQueryParameters}');

      setState(() {
        _referrerInfo = info;
        _parsedParams = info.asQueryParameters;
      });

      // Extract individual params from the referrer string.
      final referrer = info.getParam('referrer');
      final uid = info.getParam('uid');
      debugPrint('   referrer param → $referrer');
      debugPrint('   uid param     → $uid');
    } on UnsupportedError catch (_) {
      // Thrown when this method is called on a non-Android platform.
      setState(() =>
          _errorMessage = 'Install Referrer is only available on Android.');
    } on PlatformException catch (e) {
      debugPrint('❌ [Android] PlatformException: ${e.code} – ${e.message}');
      setState(() => _errorMessage = '${e.code}: ${e.message}');
    } catch (e) {
      debugPrint('⚠ [Android] Unexpected error: $e');
      setState(() => _errorMessage = e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // iOS – Clipboard deep-link check
  //
  // On iOS there is no install referrer API. Instead we check the clipboard
  // for a deep link the user may have copied before installing the app.
  // If nothing is found we fall back to probabilistic matching.
  // ---------------------------------------------------------------------------

  Future<void> _runIosDeferredAttribution() async {
    try {
      debugPrint('📋 [iOS] Checking clipboard for a deep link…');

      final result = await SmlerDeferredLink.getInstallReferrerIos(
        deepLinks: [
          'https://$_demoDomain/profile',
          'http://$_demoDomain/profile',
          '$_demoDomain/profile',
          _demoDomain,
        ],
      );

      if (result == null) {
        // No matching link in clipboard – use probabilistic matching instead.
        debugPrint(
            '⚠ [iOS] No clipboard match – falling back to probabilistic attribution.');
        setState(() => _usedProbabilisticFallback = true);
        await _runProbabilisticAttribution();
        return;
      }

      debugPrint(
          '✅ [iOS] Clipboard deep link: ${result.fullReferralDeepLinkPath}');
      debugPrint('   Query params: ${result.queryParameters}');

      setState(() {
        _iosDeepLink = result;
        _iosParams = result.queryParameters;
      });

      // Resolve the deep link to fetch full short-URL metadata.
      await _resolveAndShowDeepLink(result.fullReferralDeepLinkPath);

      debugPrint('   referrer param → ${result.getParam("referrer")}');
    } on UnsupportedError catch (_) {
      // Thrown when called on a non-iOS platform.
      setState(() => _errorMessage =
          'Clipboard deep-link check is only available on iOS.');
    } on PlatformException catch (e) {
      debugPrint('❌ [iOS] PlatformException: ${e.code} – ${e.message}');
      setState(() => _errorMessage = '${e.code}: ${e.message}');
    } catch (e) {
      debugPrint('⚠ [iOS] Unexpected error: $e');
      setState(() => _errorMessage = e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // PROBABILISTIC ATTRIBUTION (iOS only)
  //
  // Fallback when clipboard is empty. Matches the install event to a click
  // using device fingerprinting.
  // ---------------------------------------------------------------------------

  Future<void> _runProbabilisticAttribution() async {
    await _tryProbabilisticMatch(_demoDomain);
  }

  Future<void> _tryProbabilisticMatch(String domain) async {
    try {
      debugPrint('🎲 Attempting probabilistic match for domain: $domain');

      final result = await HelperReferrer.getProbabilisticMatch(
        domain: domain,
      );

      if (result.containsKey('error')) {
        debugPrint(
            '❌ Probabilistic match error: ${result['error']} - ${result['message']}');
        setState(() {
          _errorMessage = 'Probabilistic match failed: ${result['message']}';
        });
        return;
      }

      final matched = result['matched'] as bool? ?? false;
      final score = _asDouble(result['score']);

      debugPrint('✅ Probabilistic match result:');
      debugPrint('   Matched: $matched');
      debugPrint('   Score: $score');
      debugPrint('   Matched Attributes: ${result['matchedAttributes']}');

      setState(() {
        _probabilisticMatchResult = result;
      });
    } catch (e) {
      debugPrint('⚠ Error in probabilistic matching: $e');
      setState(() => _errorMessage = 'Probabilistic match error: $e');
    }
  }

  /// -------------------------------------------------------------------------
  /// UI
  /// -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stack Deferred Link Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Stack Deferred Link Demo')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Error: $_errorMessage',
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (Platform.isAndroid) {
      return _buildAndroidBody();
    } else if (Platform.isIOS) {
      return _buildIosBody();
    } else {
      return const Center(
        child: Text('This platform is not supported in this demo.'),
      );
    }
  }

  /// Android – Install Referrer flow
  Widget _buildAndroidBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_referrerInfo == null) {
      return _buildEmptyState('No install referrer data available.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Install Referrer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Raw: ${_referrerInfo!.installReferrer ?? 'empty'}'),
          const SizedBox(height: 12),
          if (_parsedParams.isEmpty)
            const Text('No parsed parameters.')
          else
            ..._parsedParams.entries.map((e) => Text('${e.key}: ${e.value}')),
          const Divider(height: 32),
          _buildDeepLinkResolutionSection(),
        ],
      ),
    );
  }

  /// iOS – Clipboard deep-link check, with probabilistic fallback
  Widget _buildIosBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_iosDeepLink == null && _probabilisticMatchResult == null) {
      return _buildEmptyState('No clipboard or probabilistic data available.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_iosDeepLink != null) ...[
            const Text('Clipboard Deep Link',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_iosDeepLink!.fullReferralDeepLinkPath),
            const SizedBox(height: 8),
            if (_iosParams.isEmpty)
              const Text('No query parameters.')
            else
              ..._iosParams.entries.map((e) => Text('${e.key}: ${e.value}')),
            const Divider(height: 32),
          ],
          if (_usedProbabilisticFallback)
            const Text(
              'No clipboard match – using probabilistic fallback.',
              style: TextStyle(color: Colors.orange),
            ),
          _buildProbabilisticMatchSection(),
          const Divider(height: 32),
          _buildDeepLinkResolutionSection(),
        ],
      ),
    );
  }

  /// Probabilistic Match Section (iOS only)
  Widget _buildProbabilisticMatchSection() {
    if (_probabilisticMatchResult == null) return const SizedBox.shrink();

    final matched = _probabilisticMatchResult!['matched'] as bool? ?? false;
    final score = _asDouble(_probabilisticMatchResult!['score']);
    final attrs =
        _asDynamicList(_probabilisticMatchResult!['matchedAttributes']);
    final pathParams =
        _asStringDynamicMap(_probabilisticMatchResult!['pathParams']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Probabilistic Match',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Matched: ${matched ? 'Yes' : 'No'}'),
        Text('Score: ${score.toStringAsFixed(3)}'),
        if (attrs.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...attrs.map((a) => Text('• $a'))
        ],
        if (pathParams != null) ...[
          const SizedBox(height: 8),
          Text('Short Code: ${pathParams['shortCode'] ?? '-'}'),
          Text('Domain: ${pathParams['domain'] ?? '-'}')
        ],
      ],
    );
  }

  /// Deep Link Resolution – shown when a deep link is opened at runtime
  Widget _buildDeepLinkResolutionSection() {
    if (_latestReceivedDeepLink == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Deep Link Opened',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(_latestReceivedDeepLink!),
        const SizedBox(height: 12),
        const Text('Resolved Response:',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (_isResolvingDeepLink)
          const CircularProgressIndicator()
        else if (_resolveDeepLinkError != null)
          Text('Error: $_resolveDeepLinkError',
              style: const TextStyle(color: Colors.red))
        else if (_resolvedDeepLinkData != null)
          Text(_formatResolvedData(_resolvedDeepLinkData!),
              style: const TextStyle(fontFamily: 'monospace'))
        else
          const Text('No data.'),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
      ),
    );
  }
}
