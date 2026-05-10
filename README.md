# Flutter Deferred Deep Link

[![Pub Version](https://img.shields.io/pub/v/smler_deferred_link)](https://pub.dev/packages/smler_deferred_link)
[![Pub Likes](https://img.shields.io/pub/likes/smler_deferred_link)](https://pub.dev/packages/smler_deferred_link)
[![Pub Points](https://img.shields.io/pub/points/smler_deferred_link)](https://pub.dev/packages/smler_deferred_link)
[![Popularity](https://img.shields.io/pub/popularity/smler_deferred_link)](https://pub.dev/packages/smler_deferred_link)

A powerful yet lightweight Flutter plugin for deferred deep linking built for real production apps.
It helps you extract referral information and deep link parameters on both Android and iOS without
heavy attribution SDKs.

## 📌 What Is Deferred Deep Linking?

Deferred deep linking allows your user to install your app after clicking a link, and still land on
the correct screen or carry referral metadata after install.

## 📘 How It Works — Deferred Deep Linking (Android + iOS)

If the user has not installed the app and they click a deep link, it will first open in the phone’s
default browser.
From the browser, the system automatically detects the platform (Android or iOS) and redirects the
user to the respective store:  


> **Android → Google Play Store**

> **iOS → Apple App Store**  

After installation and first app launch, the app will be able to read the deferred deep-link
parameters and navigate to the exact intended screen inside the app.

This is the core idea of Deferred Deep Linking — opening the correct screen after the app is
installed.

If you require direct deep linking (when the app is already installed), you should use packages like
*app_links* or *uni_links*.
This plugin focuses specifically on Deferred Deep Linking, not direct runtime linking.

You do not need Branch, Adjust, AppsFlyer, or any other paid SDK.
Everything works using native platform features.

### Platform Behavior

**Android**

We use the Google Play Install Referrer API, which is officially supported by Google.
This API lets us read details from:

```bash
https://play.google.com/store/apps/details?id=<package>&referrer=<encoded_params>

```

From the referrer parameter, we decode and route the user to the correct screen.  

**iOS**

Deferred deep linking usually works out-of-the-box for many iOS users.
However, for users with iCloud+ Private Relay enabled, their IP address is masked, preventing proper
session matching by servers.

To avoid this problem, we use an alternative solution:

✔ The deep link is copied to the clipboard

✔ When the app is opened the first time, we read the clipboard

✔ If the link matches your allowed domains, we extract parameters and navigate to the correct screen  


This ensures deferred linking works reliably, even under Private Relay.

## Backend Support (Important)

You must handle one small backend/website step:  
When a user clicks the deep link, the web page should redirect them to:

**Android**

```bash
https://play.google.com/store/apps/details?id=<your.package>&referrer=<param>%3D<value>

```

Encode your parameters properly  
The app will decode <value> after installation  


**iOS**

Your webpage should ensure the deep link is placed in the clipboard:  

```bash
example.com?referrer=<value>&page=<screen>

```

The plugin will read the clipboard to retrieve these values on first app launch.


This plugin solves both platforms:


| Platform    | How It Works                                                                                                                                      |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| **Android** | Uses official **Google Play Install Referrer API** to read the `referrer` param from Play Store.                                                  |
| **iOS**     | Reads **clipboard deep links** (URL copied before launching app). Pattern-matches domains, subdomains, and paths, then extracts query parameters. |
| **Advanced** | Optional **probabilistic matching** for enhanced attribution when traditional methods fail (requires network call).                              |

## 🚀 Why Use This Plugin?

✔ Lightweight (no SDKs like Branch / Adjust / AppsFlyer)

✔ Core features work 100% offline

✔ Optional probabilistic matching for advanced attribution

✔ Automatic iOS fallback when clipboard is empty

✔ Zero configuration on backend for basic usage

✔ Works from 1st launch

✔ Supports unlimited custom query params

✔ Works with any URL structure

✔ Subdomains + www + scheme normalization

✔ Clean, safe architecture with cached responses



## 🧠 Use Cases

✅ Track marketing campaign using:

> ?referrer=campaign123

✅ Store affiliate codes

✅ Open after-install screens:

> https://example.com/profile?uid=1001

✅ Route iOS users from Safari → clipboard → app

✅ Internal routing: /bonus?referrer=promo50

✅ Attribution without Firebase Dynamic Links / Branch

✅ Fallback attribution when clipboard is empty (iOS)

✅ Cross-platform probabilistic device fingerprinting

✅ High-confidence install-to-click matching via API


## 🏗 Architecture Overview

```text
Flutter App
|
|-- Platform.isAndroid ---------------------------|
|                                                 |
|    Android Native (Kotlin)                      |
|    - InstallReferrerClient                      |
|    - Single connection + retry                  |
|    - Cache result                               |
|    - Return Map to Dart -----> ReferrerInfo     |
|                                                 |
|-- Platform.isIOS --------------------------------|
|                                             |
iOS Clipboard Reader (Dart)                   |
- Reads Clipboard.kTextPlain                  |
- Pattern matcher (domain/path/subdomain)     |
- Parses as URI ----------------> IosClipboardDeepLinkResult
```

## 📦 Installation

Add:

```yaml
dependencies:
  smler_deferred_link: ^1.3.2
```

The plugin automatically includes:
- `http` for API calls (probabilistic matching)
- `device_info_plus` for device fingerprinting

### ⚙ Android Setup

The plugin already includes:

```gardle
implementation "com.android.installreferrer:installreferrer:2.2"
```

No permissions are required.

### 🍏 iOS Setup

Nothing special needed.

The plugin uses:

```dart
Clipboard.getData(Clipboard.kTextPlain)
```

This works on all iOS versions supported by Flutter.

🔐 Permissions
No permissions required on both platforms.

## 📚 API Reference

📌 1. **Android**: getInstallReferrerAndroid()

Reads Google Play Install Referrer once.

```dart
final info = await SmlerDeferredLink.getInstallReferrerAndroid();
```

Returns: ReferrerInfo

```dart
info.installReferrer; // raw "utm_source=...&referrer=..."
info.asQueryParameters; // parsed params Map<String, String>
info.referrerClickTimestampSeconds;
info.installBeginTimestampSeconds;
info.installVersion;info.googlePlayInstantParam;
```

Example

```dart
final info = await SmlerDeferredLink.getInstallReferrerAndroid();
final params = info.asQueryParameters;

debugPrint(params['referrer']); // campaign123
debugPrint(params['uid']); // optional
```

### Extracting shortCode and dltHeader from Path

> ReferrerInfo.extractShortCodeAndDltHeader() extracts structured path segments from the referrer URL.

Supports two formats:
- `https://domain.com/[dltHeader]/[shortCode]` - with optional dltHeader
- `https://domain.com/[shortCode]` - shortCode only

Example:

```dart
final info = await SmlerDeferredLink.getInstallReferrerAndroid();
final pathParams = info.extractShortCodeAndDltHeader();

debugPrint(pathParams['shortCode']); // e.g., "abc123"
debugPrint(pathParams['dltHeader']); // e.g., "promo" or null
```

### Tracking Clicks

> ReferrerInfo.trackClick() automatically sends tracking data to the Smler API.

This method:
- Extracts `clickId` from the `clickId` query parameter
- Extracts `shortCode` and optional `dltHeader` from the URL path
- Sends tracking data to `https://smler.in/api/v2/track/{clickId}`
- Returns `null` if `clickId` doesn't exist (no API call made)

Example:

```dart
final info = await SmlerDeferredLink.getInstallReferrerAndroid();
final response = await info.trackClick();

if (response != null) {
  debugPrint('Tracking successful: $response');
} else {
  debugPrint('No clickId found, tracking skipped');
}
```


### Extracting a Single Query Parameter

> ReferrerInfo.getParam(key) lets you safely extract a single query parameter from the install referrer string — regardless of how Google Play sends it.

This method works with:

- Full URLs (https://example.com/path?ref=123)

- URLs without schemes (example.com/path?ref=123)

- Subdomains (https://sub.example.com/...)

- Raw Android referrer strings (utm_source=google&ref=mycode)

- Any nested query formats  


✔ Example (Android Install Referrer)

```dart
final info = await SmlerDeferredLink.getInstallReferrerAndroid();
final ref = info.getParam('ref');
print(ref); // e.g. "promo123"

```

✔ Example (Multiple params)

```dart
final campaign = info.getParam('utm_campaign');
final source = info.getParam('utm_source');

```  






Throws

| Exception           | Reason                                          |
|---------------------|-------------------------------------------------|
| `UnsupportedError`  | Called on iOS/Web/Desktop                       |
| `PlatformException` | Play service unavailable, feature not supported |
| `StateError`        | Unexpected parsing issues                       |

📌 2. **iOS**: getInstallReferrerIos()
Reads clipboard → checks patterns → returns matched deep link + params.

```dart
final result = await SmlerDeferredLink.getInstallReferrerIos(deepLinks: ["https://example.com/profile","example.com","sub.example.com"]);

```

Returns: IosClipboardDeepLinkResult?

```dart
result.fullReferralDeepLinkPath; // full string
result.queryParameters; // parsed params
result.getParam("referrer"); // campaign123
result.getParam("uid");
```

### Extracting shortCode and dltHeader from Path (iOS)

> IosClipboardDeepLinkResult.extractShortCodeAndDltHeader() extracts structured path segments from the deep link URL.

Supports two formats:
- `https://domain.com/[dltHeader]/[shortCode]` - with optional dltHeader
- `https://domain.com/[shortCode]` - shortCode only

Example:

```dart
final result = await SmlerDeferredLink.getInstallReferrerIos(
  deepLinks: ["example.com"],
);

if (result != null) {
  final pathParams = result.extractShortCodeAndDltHeader();
  debugPrint(pathParams['shortCode']); // e.g., "abc123"
  debugPrint(pathParams['dltHeader']); // e.g., "promo" or null
}
```

### Tracking Clicks (iOS)

> IosClipboardDeepLinkResult.trackClick() automatically sends tracking data to the Smler API.

This method:
- Extracts `clickId` from the `clickId` query parameter
- Extracts `shortCode` and optional `dltHeader` from the URL path
- Sends tracking data to `https://smler.in/api/v2/track/{clickId}`
- Returns `null` if `clickId` doesn't exist (no API call made)

Example:

```dart
final result = await SmlerDeferredLink.getInstallReferrerIos(
  deepLinks: ["example.com"],
);

if (result != null) {
  final response = await result.trackClick();
  
  if (response != null) {
    debugPrint('Tracking successful: $response');
  } else {
    debugPrint('No clickId found, tracking skipped');
  }
}
```

Matching Rules

Accepts:

http://, https://, or no scheme

Subdomains (m.example.com, sub.example.com)

www. variants

Path must match pattern prefix (optional)


Example

```dart
final res = await SmlerDeferredLink.getInstallReferrerIos(deepLinks: ["example.com", "example.com/profile"]);

if (res != null) {
  final referrer = res.getParam('referrer');
  debugPrint("iOS Referrer: $referrer");
}

```

## � 3. **Runtime Deep Links**: resolveDeepLink()

When a user opens a deep link while the app is already installed, call this to resolve the short link
and retrieve its full metadata.

```dart
import 'package:app_links/app_links.dart';

final appLinks = AppLinks();

appLinks.uriLinkStream.listen((Uri uri) async {
  try {
    final data = await SmlerDeferredLink.resolveDeepLink(uri.toString());
    final shortCode = data['shortCode'] as String?;
    final domain    = data['domain']    as String?;
    final originalUrl = data['originalUrl'] as String?;
    print('Resolved: $shortCode on $domain → $originalUrl');
  } catch (e) {
    print('Error resolving link: $e');
  }
});
```

Pass `triggerWebhook: true` to have the Smler backend fire your configured webhook automatically as
part of the same request, without a second API call:

```dart
final data = await SmlerDeferredLink.resolveDeepLink(
  uri.toString(),
  triggerWebhook: true,
);
```

**Parameters:**
- `url` (String): The full deep link URL that was opened
- `triggerWebhook` (bool?, optional): When `true`, instructs the Smler backend to trigger the configured webhook as part of this resolution call

**Returns:** `Map<String, dynamic>` with:
- `shortCode` (String): The short URL code
- `domain` (String): The domain the link belongs to
- `dltHeader` (String?): Optional campaign/category header
- `originalUrl` (String?): The original destination URL
- Additional API fields from the Smler short-link response

**Throws** if the URL is unparseable, contains no short code, or the API returns a non-200 status.

---

## 📌 4. **Webhook Notification**: triggerWebhook()

Call this after `resolveDeepLink()` to notify the Smler backend that the link was opened. This
enables accurate click-open attribution tracking.

> **Tip:** You can skip this separate call by passing `triggerWebhook: true` directly to
> `resolveDeepLink()` (see above).

```dart
import 'package:smler_deferred_link/src/helpers.dart';

final data = await SmlerDeferredLink.resolveDeepLink(deepLinkUrl);

final shortCode = data['shortCode'] as String?;
final domain    = data['domain']    as String?;
final dltHeader = data['dltHeader'] as String?;

if (shortCode != null && domain != null) {
  await HelperReferrer.triggerWebhook(
    shortCode: shortCode,
    domain: domain,
    dltHeader: dltHeader,
  );
}
```

**Parameters:**
- `shortCode` (required): Short code from the resolved link
- `domain` (required): Domain from the resolved link
- `dltHeader` (optional): Campaign header, if present

**Returns:** `Map<String, dynamic>` — `{'success': true}` on success, or an `error` map on failure.

---

## �📊 Probabilistic Matching (Advanced Attribution)

Probabilistic matching enables accurate install attribution by analyzing device and network fingerprints when traditional methods fail or return insufficient data. This is particularly useful for iOS users when clipboard matching fails or for validating Android install referrer data.

### When to Use Probabilistic Matching

✅ **iOS Fallback**: When `getInstallReferrerIos()` returns `null` (clipboard empty or no match)

✅ **Cross-Platform Validation**: Confirm install attribution across both platforms

✅ **Enhanced Attribution**: Get additional click metadata and campaign information

### How It Works

1. **Automatic Device Detection**: Plugin automatically extracts device model, OS version, and platform
2. **API Matching**: Sends fingerprint to Smler API for probabilistic matching
3. **Confidence Score**: Returns a match score (0.0 to 1.0) indicating confidence level
4. **Smart Threshold**: Only fetch tracking data when score > 0.65 for high-confidence matches

### 📌 API: getProbabilisticMatch()

Performs probabilistic matching to link install events to clicks.

```dart
final result = await SmlerDeferredLink.getProbabilisticMatch(
  domain: 'example.com',
  clickId: 'optional-click-id', // optional
);
```

**Parameters:**
- `domain` (required): Your domain name (e.g., "example.com")
- `clickId` (optional): Click identifier for enhanced matching

**Returns:** `Map<String, dynamic>` with:
- `matched` (bool): Whether a match was found
- `score` (double): Confidence score (0.0 - 1.0)
- `matchedAttributes` (List): Attributes that matched
- `clickDetails` (Map): Details of the matched click
- `shortUrl` (Map): Complete short URL object with metadata
- `fingerprint` (Map): Device fingerprint data
- `domain` (String): Extracted domain from shortUrl
- `pathParams` (Map): Contains `shortCode`, `dltHeader`, and `domain`

**Example:**

```dart
final result = await SmlerDeferredLink.getProbabilisticMatch(
  domain: 'example.com',
);

if (result['matched'] == true) {
  final score = result['score'] as double;
  print('Match confidence: $score');
  
  if (score > 0.65) {
    // High confidence - proceed with attribution
    final pathParams = result['pathParams'];
    print('Short code: ${pathParams['shortCode']}');
    print('Domain: ${pathParams['domain']}');
  }
}
```

### 📌 API: fetchTrackingData()

Fetches detailed tracking data from the Smler API when you have a `clickId`.

```dart
final trackingData = await HelperReferrer.fetchTrackingData(
  clickId,
  pathParams,
  domain,
);
```

**Parameters:**
- `clickId` (String): The click ID from query parameters
- `pathParams` (Map<String, String?>): Map containing `shortCode` and optional `dltHeader`
- `domain` (String?): The domain name from the referrer URL

**Returns:** `Map<String, dynamic>` with API response data or error information

**Example:**

```dart
final clickDetails = result['clickDetails'] as Map<String, dynamic>?;
final clickId = clickDetails?['clickId'] as String?;
final pathParams = result['pathParams'] as Map<String, dynamic>?;

if (clickId != null && pathParams != null) {
  final trackingData = await HelperReferrer.fetchTrackingData(
    clickId,
    Map<String, String?>.from(pathParams),
    result['domain'] as String?,
  );
  
  print('Tracking data: $trackingData');
}
```

### 🔄 iOS Fallback Pattern (Recommended)

Use probabilistic matching as a fallback when clipboard matching fails on iOS:

```dart
Future<void> _loadInstallReferrerIos() async {
  try {
    final result = await SmlerDeferredLink.getInstallReferrerIos(
      deepLinks: ['example.com', 'example.com/profile'],
    );

    if (result == null) {
      // Clipboard empty or no match - fall back to probabilistic
      debugPrint('📊 Falling back to probabilistic matching...');
      await _tryProbabilisticMatch('example.com');
      return;
    }

    // Process clipboard result
    final params = result.queryParameters;
    // ... handle navigation
  } catch (e) {
    debugPrint('Error: $e');
  }
}

Future<void> _tryProbabilisticMatch(String domain) async {
  final result = await SmlerDeferredLink.getProbabilisticMatch(
    domain: domain,
  );

  if (result['matched'] == true) {
    final score = result['score'] as double;
    
    if (score > 0.65) {
      // High confidence - fetch tracking data
      final clickDetails = result['clickDetails'] as Map?;
      final clickId = clickDetails?['clickId'] as String?;
      final pathParams = result['pathParams'] as Map?;

      if (clickId != null && pathParams != null) {
        final trackingData = await HelperReferrer.fetchTrackingData(
          clickId,
          Map<String, String?>.from(pathParams),
          result['domain'] as String?,
        );
        
        // Process tracking data and navigate
        debugPrint('Attribution confirmed: $trackingData');
      }
    }
  }
}
```

### 🎯 Android Enhanced Attribution

Combine install referrer with probabilistic matching for complete attribution:

```dart
Future<void> _loadInstallReferrerAndroid() async {
  final info = await SmlerDeferredLink.getInstallReferrerAndroid();
  final params = info.asQueryParameters;
  
  // Get basic referrer data
  debugPrint('Referrer: ${info.installReferrer}');
  
  // Enhance with probabilistic matching
  final result = await SmlerDeferredLink.getProbabilisticMatch(
    domain: 'example.com',
  );
  
  if (result['matched'] == true && result['score'] > 0.65) {
    // Cross-validate attribution
    debugPrint('Probabilistic match confirms attribution');
    // ... proceed with tracking
  }
}
```

### ⚡ No Permissions Required

Device and OS information is automatically extracted using the `device_info_plus` package without requiring any special permissions. The plugin accesses:

✅ Device manufacturer and model (e.g., "Samsung Galaxy S21")

✅ OS version (e.g., "Android 13", "iOS 16.4")

✅ System name and basic hardware info

❌ No unique identifiers (IMEI, serial numbers, advertising IDs)

❌ No runtime permission dialogs

❌ No manifest/plist configuration needed

## 🧪 Full Usage Example (Android + iOS)

```dart
void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? status;
  Map<String, String> params = {};
  Map<String, dynamic>? trackingResponse;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (Platform.isAndroid) {
        final info = await SmlerDeferredLink.getInstallReferrerAndroid();
        params = info.asQueryParameters;
        status = "Android Referrer Loaded";
        
        // Track click automatically
        trackingResponse = await info.trackClick();
      } else if (Platform.isIOS) {
        final res = await SmlerDeferredLink.getInstallReferrerIos(
          deepLinks: ["example.com", "example.com/profile"],
        );
        if (res != null) {
          params = res.queryParameters;
          status = "iOS Clipboard Deep Link Loaded";
          
          // Track click automatically
          trackingResponse = await res.trackClick();
        } else {
          status = "No deep link found";
        }
      }
    } catch (e) {
      status = "Error: $e";
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext ctx) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Smler Deferred Link")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(status ?? "Loading..."),
              const SizedBox(height: 20),
              const Text("Params:", style: TextStyle(fontSize: 18)),
              ...params.entries.map((e) => Text("${e.key}: ${e.value}")),
              if (trackingResponse != null) ...[
                const SizedBox(height: 20),
                const Text("Tracking Response:", style: TextStyle(fontSize: 18)),
                Text(trackingResponse.toString()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

## 🧠 Best Practices

✔ Call API only once on first screen

The plugin caches results automatically.

✔ Store result locally

Install referrer is static and won’t change.

✔ For iOS

Use clipboard reading only on first launch, optional:

```dart
await Clipboard.setData(const ClipboardData(text: ""));
```

## 🔍 Troubleshooting

❓ **Android returns empty referrer**

Play Store did not include any referrer parameter. Consider using probabilistic matching as a fallback.

❓ **iOS returns null**

Clipboard may be empty or the link does not match any allowed pattern. Use probabilistic matching as a fallback strategy.

❓ **iOS parsing fails**

Ensure your passed URL patterns include base domains.

❓ **Cannot parse URL**

Clipboard might contain text that is not a URL.

❓ **Probabilistic match score is too low (< 0.65)**

This indicates low confidence in the match. The device fingerprint may not match any recent clicks, or multiple similar clicks exist. Only proceed with attribution if you accept lower confidence.

❓ **Probabilistic matching returns an error**

Check your network connection and ensure the domain parameter is correct. The API endpoint must be reachable.

Clipboard might contain text that is not a URL.

## ❓ FAQ

**Does this plugin track users?**

Core features (Install Referrer API & clipboard reading) are 100% offline with no network calls. Optional probabilistic matching and tracking APIs make network calls to the Smler API only when explicitly invoked.

**Can I use this without making network calls?**

Yes. Simply don't call `getProbabilisticMatch()` or `fetchTrackingData()`. The basic Install Referrer and clipboard features work completely offline.

**Can I clear Android referrer?**

No. Google Play controls it. You can ignore it after reading.

Is clipboard reading safe / allowed?

Yes, Flutter allows access to clipboard text.

Can it handle /path/subpath?

Yes. Pattern paths must match prefix.  


For more information see https://developer.android.com/google/play/installreferrer

