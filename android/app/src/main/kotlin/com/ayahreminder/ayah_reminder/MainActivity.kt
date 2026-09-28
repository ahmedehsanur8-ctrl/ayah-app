package com.ayahreminder.ayah_reminder

import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBatteryOptimizations())
                    "openAutostartSettings" -> result.success(openAutostartSettings())
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    "openTtsSettings" -> result.success(openTtsSettings())
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/compass")
            .setStreamHandler(CompassStream(this))
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations(): Boolean {
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
        if (tryStart(direct)) return true
        return tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    /** Opens the phone's text-to-speech settings (to install the Bangla voice). */
    private fun openTtsSettings(): Boolean {
        if (tryStart(Intent("com.android.settings.TTS_SETTINGS"))) return true
        return tryStart(Intent(Settings.ACTION_SETTINGS))
    }

    /** Opens the phone maker's "autostart" page. Returns false if only app info could be opened. */
    private fun openAutostartSettings(): Boolean {
        val components = listOf(
            // Xiaomi / Redmi / POCO
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            // Oppo / Realme / OnePlus (ColorOS)
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
            ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
            ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            ComponentName("com.oplus.safecenter", "com.oplus.safecenter.startupapp.StartupAppListActivity"),
            // Vivo / iQOO
            ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
            ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
            // Huawei / Honor
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
            // Samsung
            ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
            // Asus
            ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.entry.FunctionActivity"),
            // Letv
            ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"),
            // Transsion (Tecno / Infinix / itel)
            ComponentName("com.transsion.phonemaster", "com.cyin.himgr.autostart.AutoStartActivity"),
        )
        for (c in components) {
            if (tryStart(Intent().setComponent(c))) return true
        }
        tryStart(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:$packageName"))
        )
        return false
    }

    private fun tryStart(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}

/**
 * Compass heading for the Qibla screen, from the rotation-vector sensor
 * (or accelerometer + magnetometer on phones without it). When the Dart side
 * passes a location, magnetic north is corrected to true north.
 */
private class CompassStream(private val context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private var manager: SensorManager? = null
    private var declination = 0f
    private var accuracy = 3
    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasMagnet = false
    private var lastSent = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val args = arguments as? Map<*, *>
        val lat = (args?.get("lat") as? Number)?.toFloat()
        val lng = (args?.get("lng") as? Number)?.toFloat()
        if (lat != null && lng != null) {
            declination = GeomagneticField(lat, lng, 0f, System.currentTimeMillis()).declination
        }
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        manager = sm
        val rotation = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (rotation != null) {
            sm.registerListener(this, rotation, SensorManager.SENSOR_DELAY_UI)
            // Only for the accuracy (calibration) value.
            sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            }
        } else {
            val acc = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            val mag = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
            if (acc == null || mag == null) {
                events.error("NO_COMPASS", "This phone has no compass sensor", null)
                return
            }
            sm.registerListener(this, acc, SensorManager.SENSOR_DELAY_UI)
            sm.registerListener(this, mag, SensorManager.SENSOR_DELAY_UI)
        }
    }

    override fun onCancel(arguments: Any?) {
        manager?.unregisterListener(this)
        manager = null
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, value: Int) {
        if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) accuracy = value
    }

    override fun onSensorChanged(event: SensorEvent) {
        val r = FloatArray(9)
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> SensorManager.getRotationMatrixFromVector(r, event.values)
            Sensor.TYPE_ACCELEROMETER -> {
                System.arraycopy(event.values, 0, gravity, 0, 3); hasGravity = true; return
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                System.arraycopy(event.values, 0, geomagnetic, 0, 3); hasMagnet = true
                if (manager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR) != null) return
                if (!hasGravity || !SensorManager.getRotationMatrix(r, null, gravity, geomagnetic)) return
            }
            else -> return
        }
        val now = System.currentTimeMillis()
        if (now - lastSent < 50) return
        lastSent = now
        val o = FloatArray(3)
        SensorManager.getOrientation(r, o)
        var heading = Math.toDegrees(o[0].toDouble()) + declination
        heading = (heading + 360.0) % 360.0
        sink?.success(mapOf("heading" to heading, "accuracy" to accuracy))
    }
}
