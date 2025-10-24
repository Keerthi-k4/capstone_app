# Quick Start Guide - Health Connect Integration

## For Users

### How to Use the App

#### Demo Mode (Default)
1. Open the app
2. The "Today's Activity" section shows sample data
3. No setup required!

#### Switch to Actual Mode (Wear OS Data)
1. Scroll to "Today's Activity"
2. Tap the **"Demo Mode"** button (orange with science icon)
3. In the dialog, select **"Actual Mode"**
4. If prompted, tap **"Grant"** to allow permissions
5. In Health Connect screen, grant all requested permissions
6. Return to app - you're now tracking real data!

#### Requirements for Actual Mode
- Android device (Android 8+)
- Health Connect app installed (built-in on Android 14+)
- Wear OS watch paired (optional, but recommended)
- Some activity data recorded

---

## For Developers

### Quick Setup

#### 1. Install Dependencies
```bash
cd capstone_app
flutter pub get
```

#### 2. Configure FastAPI Environment
```bash
cd fast_api_routes
# Create .env file with your API key
echo "GROQ_API_KEY=your_key_here" > .env
echo "GROQ_MODEL=moonshotai/kimi-k2-instruct" >> .env
```

#### 3. Build and Run
```bash
cd ..
flutter run
```

### File Structure
```
lib/
├── models/
│   └── health_data_model.dart          # NEW: Health data model
├── services/
│   ├── health_connect_service.dart     # NEW: Health Connect service
│   └── daily_nutrition_service.dart    # MODIFIED: Uses Health Connect
└── screens/
    └── home_screen.dart                # MODIFIED: Added toggle button

android/app/src/main/kotlin/com/capstone/fitnessdiet/
├── MainActivity.kt                      # MODIFIED: Method channel handler
├── HealthConnectManager.kt             # NEW: Native Health Connect code
└── HealthConnectPermissionsActivity.kt # NEW: Privacy policy activity

fast_api_routes/
├── .env                                 # NEW: Environment variables
├── .gitignore                          # NEW: Ignore .env
└── main.py                             # MODIFIED: Loads from .env
```

### Key Components

#### HealthConnectService
```dart
// Check if actual mode is enabled
bool isDemo = await healthConnectService.isDemoMode();

// Toggle mode
await healthConnectService.setDemoMode(false); // Switch to actual

// Get today's data
HealthData data = await healthConnectService.getTodayHealthData();
print('Steps: ${data.steps}');
```

#### HealthData Model
```dart
// Demo data
HealthData demo = HealthData.demo();

// Custom data
HealthData custom = HealthData(
  steps: 5000,
  heartRate: 75,
  caloriesBurned: 300,
  exerciseMinutes: 20,
  timestamp: DateTime.now(),
);
```

### Testing

#### Test Demo Mode
```bash
# Just run the app - demo mode is default
flutter run
```

#### Test Actual Mode
```bash
# Run on real device with Health Connect
flutter run -d <device-id>

# Or use ADB for synthetic data
adb shell am broadcast -a "whs.USE_SYNTHETIC_PROVIDERS" \
  com.google.android.wearable.healthservices
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Build error on `HealthConnectManager.kt` | Update Android SDK to API 34+ |
| "Health Connect not available" | Install from Play Store or use demo mode |
| No data showing | Wait for Wear OS sync (5-15 min) |
| Permission errors | Check AndroidManifest.xml has all permissions |

### API Reference

#### Flutter Methods
```dart
// HealthConnectService
Future<bool> isDemoMode()
Future<void> setDemoMode(bool isDemo)
Future<bool> isHealthConnectAvailable()
Future<bool> requestPermissions()
Future<bool> hasPermissions()
Future<HealthData> getTodayHealthData()
Future<HealthData> getHealthDataForDate(String date)
```

#### Native Methods (MethodChannel)
```kotlin
"isAvailable" -> Boolean
"hasPermissions" -> Boolean
"requestPermissions" -> Boolean
"getTodayHealthData" -> Map<String, Any>
"getHealthDataForDate" -> Map<String, Any>
"writeHealthData" -> Boolean
"openSettings" -> void
```

### Debug Commands

```bash
# Check Health Connect status
adb shell dumpsys healthconnect

# Clear app data
adb shell pm clear com.capstone.fitnessdiet

# View logs
adb logcat | grep -E "(HealthConnect|MainActivity)"
```

---

## For Testers

### Test Cases

#### TC1: Demo Mode (Default)
1. Fresh install
2. Open app
3. ✅ "Demo Mode" button shows
4. ✅ Activity data displays: 4200 steps, 72 bpm, etc.

#### TC2: Switch to Actual Mode
1. Tap "Demo Mode" button
2. Select "Actual Mode"
3. Grant permissions
4. ✅ Button changes to "Actual Mode" (green)
5. ✅ Data updates from Health Connect

#### TC3: Mode Persistence
1. Switch to actual mode
2. Close app completely
3. Reopen app
4. ✅ Still in actual mode
5. ✅ Data persists

#### TC4: No Health Connect
1. Uninstall Health Connect
2. Try switching to actual mode
3. ✅ Error message shows
4. ✅ Stays in demo mode

#### TC5: Permission Denied
1. Switch to actual mode
2. Deny permissions
3. ✅ Error message shows
4. ✅ Reverts to demo mode

### Expected Results

| Scenario | Expected Behavior |
|----------|------------------|
| First launch | Demo mode active, sample data showing |
| Toggle button tap | Dialog opens with mode options |
| Switch to actual (success) | Green button, real data loads |
| Switch to actual (no HC) | Error snackbar, stays in demo |
| Switch to actual (no perms) | Prompt to grant, can retry |
| App restart | Last selected mode restored |

---

## Environment Variables

### FastAPI (.env)
```bash
# Required
GROQ_API_KEY=your_groq_api_key_here

# Optional
GROQ_MODEL=moonshotai/kimi-k2-instruct
```

### Security Notes
- ✅ `.env` file is gitignored
- ✅ API key not in source code
- ⚠️ Share `.env` template with team (without actual keys)
- ⚠️ Each dev needs their own API key

---

## Deployment Checklist

### Before Merging
- [ ] All files compile without errors
- [ ] Demo mode works
- [ ] Actual mode works (on test device)
- [ ] `.env` file is in `.gitignore`
- [ ] No hardcoded API keys in code
- [ ] Comments added to complex logic
- [ ] README updated

### Before Release
- [ ] Test on Android 8, 10, 12, 14
- [ ] Test with/without Health Connect
- [ ] Test with/without Wear OS
- [ ] Test permission flows
- [ ] Test mode switching
- [ ] Test data accuracy
- [ ] Update version number
- [ ] Create release notes

---

## Support

### Documentation
- Full implementation details: `HEALTH_CONNECT_IMPLEMENTATION.md`
- Official Health Connect docs: https://developer.android.com/health-and-fitness/guides/health-connect

### Common Questions

**Q: Why demo mode by default?**
A: To ensure app works for everyone, even without Health Connect or Wear OS.

**Q: Can I customize demo data?**
A: Yes, edit `HealthData.demo()` in `health_data_model.dart`.

**Q: Does this work on iOS?**
A: No, Health Connect is Android-only. iOS has HealthKit (not implemented yet).

**Q: Will this conflict with my teammates' changes?**
A: Low risk - mostly new files. See conflict resolution in main docs.

**Q: How often does data sync?**
A: Health Connect aggregates data periodically. Manual refresh can be added.

---

## Next Steps

1. **Test thoroughly** on various devices
2. **Get team feedback** on UX
3. **Consider enhancements** (background sync, more metrics)
4. **Document for users** (in-app tutorial?)
5. **Monitor for errors** in production

Happy coding! 🚀
