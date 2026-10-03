package com.ayahreminder.ayah_reminder

import android.Manifest
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (a FlutterActivity) lets recitation keep playing with the
// screen off, with media controls in the notification.
class MainActivity : AudioServiceActivity() {
    companion object {
        /** Dart has asked for the launch payload once (the engine is running). */
        private var dartStarted = false
    }

    private var permissionResult: MethodChannel.Result? = null
    private var reminderChannel: MethodChannel? = null

    /** Reminder that opened the app, until Flutter asks for it. */
    private var pendingReminderPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingReminderPayload = intent?.getStringExtra("reminder_payload")
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = intent.getStringExtra("reminder_payload") ?: return
        val ch = reminderChannel
        if (ch == null) pendingReminderPayload = payload else ch.invokeMethod("open", payload)
    }

    private fun appDetails() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(Uri.parse("package:$packageName"))

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Alarm-style ayah / hadith reminders (Reminder.kt).
        val reminders = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/reminder")
        reminderChannel = reminders
        reminders.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    Planner.saveReminders(this, call)
                    result.success(true)
                }
                "test" -> {
                    val e = org.json.JSONObject(call.argument<String>("event") ?: "{}")
                    val delay = (call.argument<Int>("seconds") ?: 60) * 1000L
                    ReminderScheduler.scheduleOnce(this, e, System.currentTimeMillis() + delay, ReminderScheduler.REQUEST_TEST)
                    result.success(true)
                }
                "stopSound" -> {
                    ReminderService.stopSound(this); result.success(true)
                }
                "snooze" -> {
                    ReminderService.snooze(this); result.success(true)
                }
                "done" -> {
                    ReminderService.stopSound(this)
                    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(ReminderService.NOTIFICATION_ID)
                    result.success(true)
                }
                "launchPayload" -> {
                    dartStarted = true
                    result.success(pendingReminderPayload)
                    pendingReminderPayload = null
                }
                else -> result.notImplemented()
            }
        }
        // The Flutter engine is cached (AudioServiceActivity), so after the
        // screen was closed a reminder opens a new activity on an engine that is
        // already running and won't ask for the launch payload again.
        val waiting = pendingReminderPayload
        if (dartStarted && waiting != null) {
            pendingReminderPayload = null
            Handler(Looper.getMainLooper()).post { reminders.invokeMethod("open", waiting) }
        }
        // When to top up the alarm plan in the background (Planner.kt).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/planner")
            .setMethodCallHandler { call, result -> Planner.handlePlanner(this, call, result) {} }
        // Full azan at prayer times (Azan.kt).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/azan")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        Planner.saveAzan(this, call)
                        result.success(true)
                    }
                    "playNow" -> {
                        AzanService.start(
                            this,
                            call.argument<String>("name") ?: "",
                            call.argument<Boolean>("fajr") ?: false,
                            System.currentTimeMillis(),
                            call.argument<String>("sound") ?: "nabawi",
                            (call.argument<Double>("volume") ?: -1.0).toFloat(),
                        )
                        result.success(true)
                    }
                    "stop" -> {
                        AzanService.stop(this); result.success(true)
                    }
                    "isPlaying" -> result.success(AzanService.isPlaying)
                    else -> result.notImplemented()
                }
            }
        // Location for prayer times and Qibla, with Android's own LocationManager
        // (no Google Play Services). It is only read on request and stays on the phone.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(locationStatus())
                    "request" -> requestLocationPermission(result)
                    "enabled" -> result.success(isLocationEnabled())
                    "get" -> getLocation(result)
                    "openAppSettings" -> result.success(
                        tryStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.parse("package:$packageName")))
                    )
                    "openLocationSettings" -> result.success(
                        tryStart(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ayah_reminder/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                    "canDrawOverlays" -> result.success(canDrawOverlays(this))
                    "openOverlaySettings" -> result.success(
                        tryStart(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).setData(Uri.parse("package:$packageName")))
                            || tryStart(appDetails())
                    )
                    "notificationsEnabled" -> result.success(
                        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
                    )
                    "openNotificationSettings" -> result.success(
                        (Build.VERSION.SDK_INT >= 26 && tryStart(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        )) || tryStart(appDetails())
                    )
                    "canScheduleExactAlarms" -> result.success(
                        Build.VERSION.SDK_INT < 31 ||
                            (getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager).canScheduleExactAlarms()
                    )
                    "openExactAlarmSettings" -> result.success(
                        (Build.VERSION.SDK_INT >= 31 && tryStart(
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).setData(Uri.parse("package:$packageName"))
                        )) || tryStart(appDetails())
                    )
                    "openFullScreenSettings" -> result.success(
                        (Build.VERSION.SDK_INT >= 34 && tryStart(
                            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).setData(Uri.parse("package:$packageName"))
                        )) || tryStart(appDetails())
                    )
                    "openAppDetails" -> result.success(tryStart(appDetails()))
                    "openMiuiPermissions" -> result.success(
                        tryStart(Intent("miui.intent.action.APP_PERM_EDITOR")
                            .setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                            .putExtra("extra_pkgname", packageName))
                            || tryStart(appDetails())
                    )
                    "openBatterySettings" -> result.success(
                        tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) || tryStart(appDetails())
                    )
                    "openSamsungBattery" -> result.success(
                        listOf(
                            "com.samsung.android.sm.battery.ui.BatteryActivity",
                            "com.samsung.android.sm.ui.battery.BatteryActivity",
                        ).any { tryStart(Intent().setClassName("com.samsung.android.lool", it)) }
                            || tryStart(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            || tryStart(appDetails())
                    )
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

    private fun canUseFullScreenIntent(): Boolean = canUseFullScreen(this)

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

    private fun hasLocationPermission(): Boolean =
        checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    /** "granted", "denied" or "deniedForever" (asked before and the phone will not ask again). */
    private fun locationStatus(): String {
        if (hasLocationPermission()) return "granted"
        val prefs = getSharedPreferences("location_permission", Context.MODE_PRIVATE)
        val askedBefore = prefs.getBoolean("asked", false)
        return if (askedBefore && !shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_COARSE_LOCATION))
            "deniedForever" else "denied"
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (hasLocationPermission()) {
            result.success("granted"); return
        }
        permissionResult?.success(locationStatus())
        permissionResult = result
        getSharedPreferences("location_permission", Context.MODE_PRIVATE).edit().putBoolean("asked", true).apply()
        requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), 4001)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4001) {
            permissionResult?.success(locationStatus())
            permissionResult = null
        }
    }

    private fun isLocationEnabled(): Boolean {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return if (Build.VERSION.SDK_INT >= 28) lm.isLocationEnabled
        else lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) || lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
    }

    /** The newest known location (under an hour old), else one fresh reading (20 s timeout). */
    @Suppress("MissingPermission", "DEPRECATION")
    private fun getLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.success(null); return
        }
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = lm.getProviders(true)
        var newest: Location? = null
        for (p in providers) {
            val l = try { lm.getLastKnownLocation(p) } catch (e: Exception) { null } ?: continue
            val n = newest
            if (n == null || l.time > n.time) newest = l
        }
        val best: Location? = newest
        fun send(l: Location?) = result.success(l?.let { mapOf("lat" to it.latitude, "lng" to it.longitude) })
        val fresh = best != null && System.currentTimeMillis() - best.time < 60 * 60 * 1000
        val provider = when {
            providers.contains(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            providers.contains(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            else -> null
        }
        if (fresh || provider == null) {
            send(best); return
        }
        val handler = Handler(Looper.getMainLooper())
        var done = false
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (done) return
                done = true
                lm.removeUpdates(this)
                send(location)
            }
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        try {
            lm.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
        } catch (e: Exception) {
            send(best); return
        }
        handler.postDelayed({
            if (!done) {
                done = true
                lm.removeUpdates(listener)
                send(best)
            }
        }, 20000)
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
