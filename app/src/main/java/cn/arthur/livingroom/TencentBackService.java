package cn.arthur.livingroom;

import android.accessibilityservice.AccessibilityService;
import android.app.usage.UsageEvents;
import android.app.usage.UsageStatsManager;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.util.Log;
import android.os.SystemClock;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

/** Adapts BACK only on Tencent's launcher root. Never reads window content. */
public class TencentBackService extends AccessibilityService {
  private boolean consumeBack;
  private long lastQuery;
  private String currentPackage = "", currentActivity = "";

  protected void onServiceConnected() { Log.i("LivingRoomBack", "Return adapter connected"); currentTencentRoot(); }

  private boolean isTencentRoot(String name) {
    return "com.ktcp.launcher.activity.LauncherHomeSingleTaskActivity".equals(name)
        || "com.ktcp.launcher.activity.LauncherHomeNormalActivity".equals(name)
        || "com.ktcp.launcher.activity.LauncherHomeExclusiveTaskActivity".equals(name);
  }

  private boolean currentTencentRoot() {
    try {
      long now = System.currentTimeMillis();
      long from = lastQuery == 0 || now < lastQuery
          ? Math.max(0, now - SystemClock.elapsedRealtime()) : lastQuery;
      UsageStatsManager manager = (UsageStatsManager) getSystemService(USAGE_STATS_SERVICE);
      UsageEvents events = manager.queryEvents(from, now);
      if (events == null) return false;
      UsageEvents.Event event = new UsageEvents.Event();
      while (events.hasNextEvent()) {
        events.getNextEvent(event);
        String pkg = event.getPackageName() == null ? "" : event.getPackageName();
        String name = event.getClassName() == null ? "" : event.getClassName();
        if (event.getEventType() == UsageEvents.Event.MOVE_TO_FOREGROUND) {
          currentPackage = pkg;
          currentActivity = name;
        } else if (event.getEventType() == UsageEvents.Event.MOVE_TO_BACKGROUND
            && currentPackage.equals(pkg) && currentActivity.equals(name)) {
          currentPackage = "";
          currentActivity = "";
        }
      }
      lastQuery = now;
      if ("com.ktcp.launcher".equals(currentPackage)) {
        Log.i("LivingRoomBack", "Current Tencent activity: " + currentActivity);
        return isTencentRoot(currentActivity);
      }
    } catch (SecurityException ignored) { }
    return false;
  }

  public void onAccessibilityEvent(AccessibilityEvent event) {
    // No window content is requested or inspected.
  }

  protected boolean onKeyEvent(KeyEvent event) {
    if (event.getKeyCode() != KeyEvent.KEYCODE_BACK) return false;
    if (event.getAction() == KeyEvent.ACTION_UP) {
      boolean handled = consumeBack;
      consumeBack = false;
      return handled;
    }
    if (consumeBack) return true;
    if (event.getAction() != KeyEvent.ACTION_DOWN || event.getRepeatCount() != 0
        || !currentTencentRoot()) return false;
    Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
    ResolveInfo resolved = getPackageManager().resolveActivity(home, 0);
    if (resolved == null || resolved.activityInfo == null
        || !getPackageName().equals(resolved.activityInfo.packageName)) return false;
    consumeBack = true;
    home.setClass(this, HomeActivity.class);
    home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
    startActivity(home);
    Log.i("LivingRoomBack", "BACK from Tencent root to selected home");
    return true;
  }

  public void onInterrupt() { currentPackage = ""; currentActivity = ""; lastQuery = 0; }
}
