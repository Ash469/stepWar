package com.stepwars.stepwarsnew_app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "auto_start_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAutoStart" -> {
                        openAutoStartSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openAutoStartSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        var intent: Intent? = null

        try {
            when (manufacturer) {
                "xiaomi", "redmi" -> {
                    intent = createIntent(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
                "oppo" -> {
                    intent = createIntent(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                    )
                }
                "vivo" -> {
                    intent = createIntent(
                        "com.iqoo.secure",
                        "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
                    )
                }
                "huawei", "honor" -> {
                    intent = createIntent(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                }
                "oneplus" -> {
                    intent = createIntent(
                        "com.oneplus.security",
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                    )
                }
                "samsung" -> {
                    // Samsung aggressively kills apps, no true autostart setting
                    intent = createIntent(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity"
                    )
                }
                "asus" -> {
                    intent = createIntent(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.MainActivity"
                    )
                }
            }

            // If manufacturer intent exists & is valid → open it
            if (intent != null && isIntentAvailable(intent)) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return
            }

            // Fallback: app-specific settings
            openAppDetailsSettings()

        } catch (_: Exception) {
            // Final fallback
            openMainSettings()
        }
    }

    private fun createIntent(pkg: String, activity: String): Intent {
        return Intent().apply {
            component = ComponentName(pkg, activity)
        }
    }

    private fun isIntentAvailable(intent: Intent): Boolean {
        val pm: PackageManager = packageManager
        val resolveInfo = pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo.isNotEmpty()
    }

    private fun openAppDetailsSettings() {
        val settingsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        settingsIntent.data = Uri.parse("package:$packageName")
        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(settingsIntent)
    }

    private fun openMainSettings() {
        val settingsIntent = Intent(Settings.ACTION_SETTINGS)
        settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(settingsIntent)
    }
}
