# Health Connect Data Sync Issue - Fix Guide

## Problem
Your app shows 883 steps and 219 calories, but your OnePlus Watch shows 1719 steps. This is because Health Connect doesn't have the data from your watch yet.

## Why This Happens
- Health Connect is a central hub that aggregates data from various apps
- Your OnePlus Watch stores data in its own app (likely "OnePlus Health" or "OnePlus Watch" app)
- That app needs to be configured to **write** data to Health Connect
- Right now, Health Connect is reading data from your phone's step counter, not your watch

## Solutions

### Solution 1: Connect OnePlus Health App to Health Connect

1. **Open OnePlus Health/Watch App**
   - Find the app that manages your OnePlus Watch
   - Usually called "OnePlus Health", "OnePlus Watch", or "OHealth"

2. **Find Health Connect Settings**
   - Go to Settings → Connected Apps
   - OR Settings → Data Sharing
   - OR Settings → Permissions

3. **Enable Health Connect Integration**
   - Look for "Health Connect" or "Google Health Connect"
   - Toggle it ON
   - Grant all permissions (Steps, Heart Rate, Calories, Exercise)

4. **Trigger a Sync**
   - Open your OnePlus Health app
   - Pull down to refresh
   - Wait a few moments for sync

5. **Return to Your App**
   - Close and reopen your Diet & Fitness app
   - The data should now match your watch

### Solution 2: Check Health Connect Data Sources

1. **Open Health Connect App**
   ```
   Settings → Apps → Health Connect
   OR search "Health Connect" in settings
   ```

2. **Check Data Sources**
   - Tap "Browse data"
   - Tap "Steps" 
   - See which apps are providing data
   - You should see "OnePlus Health" or similar listed

3. **Set Priority**
   - If multiple apps provide steps data, Health Connect uses priority
   - Go to "Data sources and priority"
   - Make sure OnePlus Health/Watch app is at the top for:
     - Steps
     - Heart Rate
     - Calories
     - Exercise

### Solution 3: Manual Sync via Health Connect

1. **Open Health Connect**
2. **Tap "App permissions"**
3. **Find OnePlus Health/Watch app**
4. **Grant WRITE permissions** for:
   - Steps ✅
   - Heart Rate ✅
   - Active calories burned ✅
   - Exercise ✅

5. **Force sync:**
   - Open OnePlus Health app
   - Go to a specific metric (like Steps)
   - This often triggers a sync

### Solution 4: Check Google Play Services

The logs show Google Play Services errors. Try:

1. **Update Google Play Services**
   - Open Play Store
   - Search "Google Play services"
   - Update if available

2. **Clear Cache**
   ```
   Settings → Apps → Google Play services
   Storage → Clear Cache (NOT Clear Data)
   ```

3. **Restart Phone**
   - Sometimes sync issues are resolved with a restart

## Verify the Fix

After trying the above:

1. **Check Health Connect App**
   - Open Health Connect
   - Browse data → Steps
   - Verify the count matches your watch (1719)

2. **Refresh Your App**
   - Open your Diet & Fitness app
   - Pull down to refresh OR close and reopen
   - The steps should now show 1719

3. **Test Real-Time Sync**
   - Walk around for a few minutes
   - Check your watch (steps increase)
   - Refresh your app
   - Verify the app updates with new steps

## Understanding the Data Flow

```
OnePlus Watch (1719 steps)
        ↓
OnePlus Health App (needs sync enabled)
        ↓
Health Connect (currently shows 883 - wrong source)
        ↓
Your Diet & Fitness App (shows whatever Health Connect has)
```

**Goal**: Make sure OnePlus Health app is writing to Health Connect

## If Nothing Works

If OnePlus Watch/Health app doesn't support Health Connect yet:

### Workaround: Use Google Fit as Bridge

1. **Install Google Fit**
2. **Connect OnePlus Watch to Google Fit**
3. **Connect Google Fit to Health Connect**

This creates: Watch → OnePlus Health → Google Fit → Health Connect → Your App

### Alternative: Check for App Updates

- OnePlus Health app might need an update to support Health Connect
- Check Play Store for updates
- Look for "Health Connect integration" in update notes

## Common Issues

### "OnePlus Health doesn't show Health Connect option"
- Update the app from Play Store
- Some older versions don't support Health Connect
- You may need to use Google Fit as a bridge

### "Steps still don't match after sync"
- Check data source priority in Health Connect
- Multiple apps might be writing steps data
- Make sure OnePlus Health is priority #1

### "Data updates after several minutes"
- Normal behavior - sync isn't instant
- Health Connect syncs every 15-30 minutes typically
- Force sync by opening OnePlus Health app

## Expected Results

Once properly configured:
- ✅ Steps: Should match your watch (1719)
- ✅ Heart Rate: Should show current BPM from watch (77)
- ✅ Calories: Should match watch calculations
- ✅ Exercise: Should show workout sessions from watch
- ✅ Updates: Should sync every 15-30 minutes automatically

---

**Next Step**: Try Solution 1 first - open your OnePlus Health/Watch app and look for Health Connect settings.
