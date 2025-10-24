# Permission Flow Fix - Testing Guide

## What Was Fixed

### Problem
- When switching to "Actual Mode", clicking "Grant" in the permission dialog didn't open Health Connect settings
- The app immediately showed "Permissions not granted. Using demo mode."
- Health Connect permission screen never appeared

### Root Cause
- The original code used `ACTION_REQUEST_PERMISSIONS` Intent which wasn't launching properly
- The permission request flow was using an unreliable Intent action

### Solution
1. Changed Intent action to `ACTION_MANAGE_HEALTH_PERMISSIONS` which is more reliable
2. Added package name extra to try opening directly to app's permission page
3. Updated dialog UI to clearly explain what will happen
4. Changed button text from "Grant" to "Open Settings" for clarity

## How to Test

### Step 1: Clean Build
```bash
cd c:\Users\krish\Documents\capstone_app
flutter clean
flutter pub get
flutter build apk --debug
```

### Step 2: Install on Device
```bash
flutter install
```
Or manually install the APK from `build/app/outputs/flutter-apk/app-debug.apk`

### Step 3: Test Permission Flow

1. **Start in Demo Mode** (default)
   - Open the app
   - Verify you see the demo data:
     - Steps: 4200
     - Calories: 219
     - Exercise: 15 min
   - Look for orange "Demo Mode" button under "Today's Activity"

2. **Switch to Actual Mode**
   - Tap the "Demo Mode" button
   - In the mode selection dialog, tap "Actual Mode"
   - **Expected**: Permission dialog appears with clear instructions

3. **Grant Permissions**
   - Read the dialog message explaining what permissions are needed
   - Tap "Open Settings" button
   - **Expected**: Health Connect app opens, showing permission management screen
   - **Alternative**: If the above doesn't work, Health Connect home screen opens

4. **In Health Connect**
   - If you're on the permission management screen for your app:
     - Toggle ON all four permissions:
       - ✅ Steps
       - ✅ Heart Rate
       - ✅ Calories Burned  
       - ✅ Exercise Sessions
     - Tap the back button to return to your app
   
   - If you're on Health Connect home screen:
     - Tap "App permissions" or similar
     - Find "capstone_app" in the list
     - Tap it and grant all permissions
     - Navigate back to your app

5. **Return to App**
   - When you return, the app will automatically check permissions (onResume)
   - **Expected**: You see green "Actual Mode" button
   - **Expected**: Snackbar shows "Switched to Actual Mode"

6. **Verify Actual Mode**
   - The activity data should now show:
     - Real data from Health Connect (if available)
     - OR zeros if no health data sources are connected yet
   - Button shows green "Actual Mode" indicating active mode

### Step 4: Test Mode Persistence

1. Close the app completely (swipe away from recents)
2. Reopen the app
3. **Expected**: Still in "Actual Mode" (green button)
4. **Expected**: Permissions still granted (no dialog)

### Step 5: Test Mode Toggle

1. Tap the green "Actual Mode" button
2. Select "Demo Mode" from dialog
3. **Expected**: Immediately switches to demo data (4200 steps, etc.)
4. **Expected**: Button changes to orange "Demo Mode"
5. Tap "Demo Mode" button again
6. Select "Actual Mode"
7. **Expected**: No permission dialog (already granted)
8. **Expected**: Switches to actual data immediately

## Troubleshooting

### Issue: Health Connect not installed
**Symptom**: Error "Health Connect not available on this device"
**Solution**: 
```bash
# Open Play Store and search for "Health Connect"
# OR use this command to open Play Store page:
adb shell am start -a android.intent.action.VIEW -d "market://details?id=com.google.android.apps.healthdata"
```

### Issue: Health Connect opens but no permissions screen
**Symptom**: Health Connect home screen opens but not permission management
**Solution**: 
1. In Health Connect app, tap menu (three dots or hamburger)
2. Find "App permissions" or "Manage permissions"
3. Look for "capstone_app" in the list
4. Tap it and grant permissions manually
5. Return to app

### Issue: Permissions granted but showing zeros
**Symptom**: All permissions granted, but activity data shows 0 steps, 0 calories
**Solution**: This is EXPECTED if no health data sources are connected to Health Connect
- Health Connect aggregates data from various sources (Wear OS, fitness apps, etc.)
- If no sources are connected, data will be zero
- Connect a Wear OS device or fitness app to populate data

### Issue: Still getting "Permissions not granted"
**Symptom**: After granting permissions, still seeing demo mode
**Solution**:
1. Check logcat for errors:
   ```bash
   adb logcat | grep -i "health\|permission\|capstone"
   ```
2. Verify permissions in Health Connect app manually
3. Try force-closing the app and reopening
4. Check if Health Connect app needs update

## Expected Behavior Summary

| Scenario | Expected Behavior |
|----------|------------------|
| First launch | Demo mode active (orange button), demo data shown |
| Tap "Demo Mode" button | Dialog shows both mode options |
| Select "Actual Mode" (no perms) | Permission request dialog appears |
| Tap "Open Settings" | Health Connect opens to permissions |
| Grant all permissions | Return to app, actual mode active |
| No data sources | Shows 0 for all metrics (valid state) |
| Has data sources | Shows real activity data |
| Switch back to Demo | Immediately shows demo data (4200 steps) |
| App restart | Remembers last selected mode |

## Files Modified

1. `android/app/src/main/kotlin/com/capstone/fitnessdiet/HealthConnectManager.kt`
   - Changed Intent action to `ACTION_MANAGE_HEALTH_PERMISSIONS`
   - Added package name extra for direct navigation

2. `lib/screens/home_screen.dart`
   - Updated permission dialog message with clear instructions
   - Changed button text to "Open Settings"
   - Added list of required permissions in dialog

## Next Steps After Testing

1. If permissions are granted successfully, connect Wear OS device or fitness apps to Health Connect
2. Generate some activity (walk around) to see real-time data
3. Verify data updates when switching between screens
4. Test with different time periods (if implemented)

---

**Note**: The first time you grant permissions, you may need to wait a few moments for Health Connect to sync data from connected sources.
