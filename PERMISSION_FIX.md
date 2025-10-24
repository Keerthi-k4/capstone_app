# Health Connect Permission Fix

## Issue
The permission request was failing with error:
```
No Activity found to handle Intent { act=androidx.activity.result.contract.action.REQUEST_PERMISSIONS }
```

## Root Causes
1. Using deprecated `startActivityForResult()` and `onActivityResult()`
2. Health Connect's permission contract wasn't being handled properly
3. Minimum SDK was 24, but Health Connect requires 26+

## Fixes Applied

### 1. Updated Minimum SDK Version
**File:** `android/app/build.gradle`
- Changed `minSdkVersion flutter.minSdkVersion` to `minSdkVersion 26`
- Health Connect requires API 26 (Android 8.0) or higher

### 2. Modernized Permission Flow
**File:** `android/app/src/main/kotlin/.../MainActivity.kt`
- Removed deprecated `ActivityResultLauncher` and `onActivityResult()`
- Added `onResume()` to check permissions when user returns from Health Connect
- Set `awaitingPermissionResult` flag to track permission state

### 3. Simplified Permission Request
**File:** `android/app/src/main/kotlin/.../HealthConnectManager.kt`
- Directly launch Health Connect permission screen using Intent
- Fallback to Health Connect settings if permission screen unavailable

## How It Works Now

1. User taps "Actual Mode" button
2. App checks if Health Connect is available
3. If permissions not granted, launches Health Connect permission screen
4. User grants/denies permissions in Health Connect
5. When user returns to app, `onResume()` checks permission status
6. App updates UI based on permission result

## Testing Steps

1. Run `flutter run` on your device
2. App should start in Demo Mode
3. Tap the "Demo Mode" button
4. Select "Actual Mode" from dialog
5. Health Connect permission screen should open
6. Grant the following permissions:
   - Read heart rate
   - Read steps
   - Read active calories burned
   - Read exercise
7. Return to app - should now show "Actual Mode" (green button)
8. Activity data will update from Health Connect

## Note on Data
- **First time**: May show zeros if no data in Health Connect yet
- **With Wear OS watch**: Data syncs from watch to phone to Health Connect (5-15 min delay)
- **Without watch**: Phone's step counter and any other health apps writing to Health Connect

## Troubleshooting

### Still showing zeros in Actual Mode?
1. Check if Health Connect has any data sources:
   - Open Health Connect app
   - Look at "Data and access" section
   - Verify apps are contributing data

2. Manually add some data:
   - Open Health Connect app
   - Add manual exercise session or steps
   - Return to your app and check

3. Verify watch is syncing:
   - Open Wear OS app on phone
   - Check sync status
   - Force sync if needed

### Permission screen doesn't open?
- Health Connect may not be installed
- Install from Google Play Store
- Or the app will fallback to demo mode automatically

## Files Modified
- `android/app/build.gradle` - Updated minSdkVersion to 26
- `android/app/src/main/kotlin/.../MainActivity.kt` - Modern permission handling
- `android/app/src/main/kotlin/.../HealthConnectManager.kt` - Simplified permission request

## Next Steps
- Test with real Wear OS device
- Add some activity data to Health Connect manually
- Verify data appears in the app's activity rings
