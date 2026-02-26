import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smler_deferred_link/smler_deferred_link.dart';
import 'package:smler_deferred_link/src/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 Stack Deferred Link example starting on platform: ${Platform.operatingSystem}');
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
  // Android data
  ReferrerInfo? _referrerInfo;
  Map<String, String> _parsedParams = {};

  // iOS data
  IosClipboardDeepLinkResult? _iosDeepLink;
  Map<String, String> _iosParams = {};

  // Probabilistic match data
  Map<String, dynamic>? _probabilisticMatchResult;
  Map<String, dynamic>? _trackingData;
  bool _usedProbabilisticFallback = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    final appLinks = AppLinks();
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('smler_deferred_link.first_launch') ?? true;

    if (isFirstLaunch) {
      // Perform navigation logic here
      debugPrint('Navigating to the deferred link destination...');
      _loadPlatformData();
      // Mark first-launch check completed
      await prefs.setBool('smler_deferred_link.first_launch', false);
    } else {
      appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          debugPrint('Received deep link: $uri');
          // Handle deep link navigation here
        }
      }, onError: (err) {
        debugPrint('Error receiving deep link: $err');
      });
    }
  }

  /// -------------------------------------------------------------------------
  /// MAIN LOGIC – Platform-aware entry
  /// -------------------------------------------------------------------------
  Future<void> _loadPlatformData() async {
    try {
      if (Platform.isAndroid) {
        await _loadInstallReferrerAndroid();
      } else if (Platform.isIOS) {
        await _loadInstallReferrerIos();
      } else {
        setState(() {
          _errorMessage = 'Platform not supported.';
        });
      }
    } catch (e) {
      debugPrint('⚠ Unexpected Error in _loadPlatformData: $e');
      setState(() => _errorMessage = e.toString());
    }
  }

  /// -------------------------------------------------------------------------
  /// ANDROID – Load Install Referrer
  /// -------------------------------------------------------------------------
  Future<void> _loadInstallReferrerAndroid() async {
    try {
      debugPrint('📥 Fetching Android Install Referrer…');

      final info = await SmlerDeferredLink.getInstallReferrerAndroid();

      debugPrint('✅ Install Referrer fetched successfully:');
      debugPrint('Raw: ${info.installReferrer}');
      debugPrint('Parsed params: ${info.asQueryParameters}');

      setState(() {
        _referrerInfo = info;
        _parsedParams = info.asQueryParameters;
      });

      // -------------------------------------------------------
      // NEW: Android specific param extraction
      // -------------------------------------------------------
      final refParam = info.getParam("referrer");
      debugPrint("Android getParam('referrer') => $refParam");

      final uidParam = info.getParam("uid");
      debugPrint("Android getParam('uid') => $uidParam");

      // -------------------------------------------------------
      // Probabilistic Matching Example
      // -------------------------------------------------------
      await _tryProbabilisticMatch('go.singh3y.dev');
    } on UnsupportedError catch (_) {
      debugPrint(
        '⚠ Install Referrer is not supported on this platform (iOS/web/desktop).',
      );
      setState(() => _errorMessage = 'Not supported on this platform');
    } on PlatformException catch (e) {
      debugPrint('❌ Plugin Error:');
      debugPrint('Code: ${e.code}');
      debugPrint('Message: ${e.message}');
      setState(() => _errorMessage = '${e.code}: ${e.message}');
    } catch (e) {
      debugPrint('⚠ Unexpected Error (Android): $e');
      setState(() => _errorMessage = e.toString());
    }
  }

  /// -------------------------------------------------------------------------
  /// iOS – Check clipboard for deep link
  /// -------------------------------------------------------------------------
  Future<void> _loadInstallReferrerIos() async {
    try {
      debugPrint('📥 Checking iOS clipboard for deep link…');

      final result = await SmlerDeferredLink.getInstallReferrerIos(
        deepLinks: [
          'https://go.singh3y.dev/profile',
          'http://go.singh3y.dev/profile',
          'go.singh3y.dev/profile',
          'go.singh3y.dev',
        ],
      );

      if (result == null) {
        debugPrint('⚠ No matching deep link found in clipboard.');
        debugPrint('🔄 Falling back to probabilistic matching...');
        
        // Fall back to probabilistic matching when clipboard is empty
        setState(() {
          _usedProbabilisticFallback = true;
        });
        await _tryProbabilisticMatch('go.singh3y.dev');
        return;
      }

      debugPrint('✅ iOS deep link found: ${result.fullReferralDeepLinkPath}');
      debugPrint('Query params: ${result.queryParameters}');

      setState(() {
        _iosDeepLink = result;
        _iosParams = result.queryParameters;
      });

      final referrer = result.getParam('referrer');
      debugPrint('iOS getParam("referrer") => $referrer');
    } on UnsupportedError catch (e) {
      debugPrint('Not supported on this platform (iOS method): $e');
      setState(() => _errorMessage = 'Not supported on this platform');
    } on PlatformException catch (e) {
      debugPrint('❌ iOS Clipboard Error: ${e.code} ${e.message}');
      setState(() => _errorMessage = '${e.code}: ${e.message}');
    } catch (e) {
      debugPrint('⚠ Unexpected Error (iOS): $e');
      setState(() => _errorMessage = e.toString());
    }
  }

  /// -------------------------------------------------------------------------
  /// Probabilistic Matching
  /// -------------------------------------------------------------------------
  Future<void> _tryProbabilisticMatch(String domain) async {
    try {
      debugPrint('🎲 Attempting probabilistic match for domain: $domain');

      final result = await HelperReferrer.getProbabilisticMatch(
        domain: domain,
      );

      if (result.containsKey('error')) {
        debugPrint('❌ Probabilistic match error: ${result['error']} - ${result['message']}');
        setState(() {
          _errorMessage = 'Probabilistic match failed: ${result['message']}';
        });
        return;
      }

      final matched = result['matched'] as bool? ?? false;
      final score = result['score'] as double? ?? 0.0;

      debugPrint('✅ Probabilistic match result:');
      debugPrint('   Matched: $matched');
      debugPrint('   Score: $score');
      debugPrint('   Matched Attributes: ${result['matchedAttributes']}');

      setState(() {
        _probabilisticMatchResult = result;
      });

      // If match score is high enough (> 0.65), fetch tracking data
      if (matched && score > 0.65) {
        debugPrint('🎯 High confidence match (score: $score > 0.65)');
        debugPrint('📊 Fetching tracking data...');

        final pathParams = result['pathParams'] as Map<String, dynamic>?;
        final clickDetails = result['clickDetails'] as Map<String, dynamic>?;
        final clickId = clickDetails?['id'] as String?;

        if (clickId != null && pathParams != null) {
          await _fetchTrackingData(
            clickId,
            Map<String, String?>.from(pathParams),
            result['domain'] as String?,
          );
        } else {
          debugPrint('⚠ Missing clickId or pathParams for tracking data');
        }
      } else {
        debugPrint('⚠ Match score too low ($score <= 0.65), skipping tracking data fetch');
      }
    } catch (e) {
      debugPrint('⚠ Error in probabilistic matching: $e');
      setState(() => _errorMessage = 'Probabilistic match error: $e');
    }
  }

  /// -------------------------------------------------------------------------
  /// Fetch Tracking Data
  /// -------------------------------------------------------------------------
  Future<void> _fetchTrackingData(
    String clickId,
    Map<String, String?> pathParams,
    String? domain,
  ) async {
    try {
      debugPrint('📡 Fetching tracking data for clickId: $clickId');

      final trackingData = await HelperReferrer.fetchTrackingData(
        clickId,
        pathParams,
        domain,
      );

      if (trackingData.containsKey('error')) {
        debugPrint('❌ Tracking data error: ${trackingData['error']} - ${trackingData['message']}');
        return;
      }

      debugPrint('✅ Tracking data fetched successfully:');
      debugPrint('   Data: $trackingData');

      setState(() {
        _trackingData = trackingData;
      });
    } catch (e) {
      debugPrint('⚠ Error fetching tracking data: $e');
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

  /// Android UI – show referrer & parsed params
  Widget _buildAndroidBody() {
    if (_referrerInfo == null && _probabilisticMatchResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎯 Install Referrer Details (Android)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_referrerInfo != null) ...[
            Text('Raw Referrer: ${_referrerInfo!.installReferrer}'),
            const SizedBox(height: 12),
            const Text(
              'Parsed Parameters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_parsedParams.isEmpty)
              const Text('No query parameters found.')
            else
              ..._parsedParams.entries.map(
                (e) => Text('• ${e.key} = ${e.value}'),
              ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          _buildProbabilisticMatchSection(),
        ],
      ),
    );
  }

  /// iOS UI – show full deep link & query params
  Widget _buildIosBody() {
    if (_iosDeepLink == null && _probabilisticMatchResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🍎 Clipboard Deep Link (iOS)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_iosDeepLink != null) ...[
            Text('Full Deep Link: ${_iosDeepLink!.fullReferralDeepLinkPath}'),
            const SizedBox(height: 12),
            const Text(
              'Query Parameters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_iosParams.isEmpty)
              const Text('No query parameters found.')
            else
              ..._iosParams.entries.map((e) => Text('• ${e.key} = ${e.value}')),
          ],
          if (_usedProbabilisticFallback) ...[
            const Text(
              '⚠ No clipboard match found',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              '🔄 Using Probabilistic Fallback',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          _buildProbabilisticMatchSection(),
        ],
      ),
    );
  }

  /// Probabilistic Match Section
  Widget _buildProbabilisticMatchSection() {
    if (_probabilisticMatchResult == null) {
      return const SizedBox.shrink();
    }

    final matched = _probabilisticMatchResult!['matched'] as bool? ?? false;
    final score = _probabilisticMatchResult!['score'] as double? ?? 0.0;
    final matchedAttributes = _probabilisticMatchResult!['matchedAttributes'] as List?;
    final pathParams = _probabilisticMatchResult!['pathParams'] as Map?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎲 Probabilistic Match Results',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Matched: ${matched ? "✅ Yes" : "❌ No"}',
          style: TextStyle(
            color: matched ? Colors.green : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text('Confidence Score: ${score.toStringAsFixed(3)}'),
        const SizedBox(height: 8),
        if (score > 0.65)
          const Text(
            '🎯 High confidence (> 0.65) - Tracking data fetched',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
          )
        else
          const Text(
            '⚠ Low confidence (<= 0.65) - Skipped tracking',
            style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: 12),
        if (matchedAttributes != null && matchedAttributes.isNotEmpty) ...[
          const Text(
            'Matched Attributes:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...matchedAttributes.map((attr) => Text('• $attr')),
          const SizedBox(height: 12),
        ],
        if (pathParams != null) ...[
          const Text(
            'Path Parameters:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Short Code: ${pathParams['shortCode'] ?? 'N/A'}'),
          Text('DLT Header: ${pathParams['dltHeader'] ?? 'N/A'}'),
          Text('Domain: ${pathParams['domain'] ?? 'N/A'}'),
          const SizedBox(height: 12),
        ],
        if (_trackingData != null) ...[
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            '📊 Tracking Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Data: ${_trackingData.toString()}'),
        ],
      ],
    );
  }
}
