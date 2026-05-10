## 1.3.2
- **SmlerDeferredLink.getProbabilisticMatch()**
  - Exposed `getProbabilisticMatch()` directly on `SmlerDeferredLink` (previously only available via `HelperReferrer`), removing the need to import `src/helpers.dart`
- **Example**
  - Removed internal `src/helpers.dart` import; probabilistic matching now calls `SmlerDeferredLink.getProbabilisticMatch()` via the public API
  - Android: added automatic probabilistic fallback when `clickId` is absent in the Play Store referrer string
  - Probabilistic attribution section updated to cover both Android and iOS scenarios

## 1.3.1
- **resolveDeepLink / resolveDeepLinkData**
  - Added optional `triggerWebhook` parameter; when provided, it is forwarded to the Smler `/api/v1/short` endpoint as a query param, letting the backend fire the configured webhook automatically in the same request
- **Example**
  - Updated `_resolveAndShowDeepLink` to pass `triggerWebhook: true` to `SmlerDeferredLink.resolveDeepLink()`, replacing the previous two-step manual `HelperReferrer.triggerWebhook()` call

## 1.3.0
- **Runtime Deep Link Resolution**
  - Added `SmlerDeferredLink.resolveDeepLink(String url)` to resolve short links at runtime and extract full metadata (`shortCode`, `domain`, `dltHeader`, `originalUrl`)
  - Added `HelperReferrer.resolveDeepLinkData(String url)` as the underlying helper
- **Webhook Integration**
  - Added `HelperReferrer.triggerWebhook({required String shortCode, required String domain, String? dltHeader})` to notify the Smler backend when a deep link is opened
- **Documentation**
  - README updated with `resolveDeepLink()` and `triggerWebhook()` API reference and usage examples

## 1.2.0
- **Probabilistic Matching & Advanced Attribution**
  - Added `HelperReferrer.getProbabilisticMatch()` for device fingerprint-based install attribution
  - Automatic device and OS detection (no permissions required)
  - Confidence score-based matching (0.0 - 1.0 scale)
  - iOS fallback strategy when clipboard matching fails
  - Android enhanced attribution support
- **API Integration**
  - Added `HelperReferrer.fetchTrackingData()` for detailed tracking information
  - Smart threshold logic (only fetch tracking when score > 0.65)
  - Integration with Smler API for probabilistic matching endpoint
- **Dependencies**
  - Added `device_info_plus: ^10.1.0` for automatic device fingerprinting
  - No special permissions required for device info access
- **Example Updates**
  - Enhanced example app with probabilistic matching demonstration
  - iOS fallback pattern implementation
  - Visual indicators for match confidence and tracking status
- **Documentation**
  - Comprehensive README updates with probabilistic matching guide
  - Complete API reference for new methods
  - Code examples for iOS fallback and Android attribution

## 1.1.1
  - Support for passing custom domain in payload

## 1.1.0
  - Added a dedicated function for tracking deferred deep link 

## 1.0.1
  - Patch release
  - Added function to extract shortCode and dltHeader

## 1.0.0
  - Launch version 1 of smler flutter package