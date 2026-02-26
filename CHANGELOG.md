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