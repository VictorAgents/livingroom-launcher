package cn.arthur.livingroom;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

/** The app-grid icon opens the same HOME entry as the remote Home button. */
public class OpenHomeActivity extends Activity {
  public void onCreate(Bundle state) {
    super.onCreate(state);
    Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
    home.setClass(this, HomeActivity.class);
    home.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
    startActivity(home);
    finish();
  }
}
