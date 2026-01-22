import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smler_deferred_link/smler_deferred_link.dart';
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
        debugPrint('No matching deep link found in clipboard.');
        setState(() {
          _errorMessage = 'No matching deep link found in clipboard.';
        });
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
    if (_referrerInfo == null) {
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
      ),
    );
  }

  /// iOS UI – show full deep link & query params
  Widget _buildIosBody() {
    if (_iosDeepLink == null) {
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
      ),
    );
  }
}
