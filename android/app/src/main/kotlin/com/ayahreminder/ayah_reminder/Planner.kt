package com.ayahreminder.ayah_reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin

/**
 * Keeps the alarms from running out when the app is not opened.
 *
 * The prayer times, sehri/iftar and the daily ayah are calculated in Dart, so
 * the plan (35 days of reminders, azan and sehri; 21 of adhkar) is made by the
 * app. Dart saves when the plan must be topped up ("refreshAt", 3 days later).
 * When an alarm rings, after a restart, and once a day ([PlannerReceiver]),
 * [Planner.maybeRun] checks that time and, if it has passed, runs the same Dart
 * planning in the background (`backgroundTopUp` in main.dart) without opening
 * the app. So at least 30 days of alarms (14 of adhkar) are always planned.
 */
object Planner {
    private const val PREFS = "planner"
    private const val DAY = 24 * 60 * 60 * 1000L
    private const val REQUEST_DAILY = 7401

    /** Longest a background run may take before it is stopped. */
    private const val TIMEOUT_MS = 45_000L

    @Volatile
    private var running = false

    /** Saved by Dart after planning. */
    fun planned(context: Context, refreshAt: Long, until: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("refreshAt", refreshAt)
            .putLong("until", until)
            .commit()
        scheduleDaily(context)
    }

    /** True when the plan must be topped up (or was never made by this version). */
    fun needed(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val refreshAt = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("refreshAt", 0L)
        return now >= refreshAt
    }

    /** Runs the Dart planning when needed (always with [force]); calls [done] when finished. */
    fun maybeRun(context: Context, force: Boolean, done: () -> Unit) {
        if (!force && !needed(context)) {
            done()
            return
        }
        run(context, done)
    }

    /** The daily check, so the plan is topped up even if no alarm rings. */
    fun scheduleDaily(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            context, REQUEST_DAILY,
            Intent(context, PlannerReceiver::class.java).setAction("com.ayahreminder.PLANNER_DAILY"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Inexact is fine: it only needs to run about once a day.
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + DAY, pi)
    }

    /** Starts a background Flutter engine at `backgroundTopUp` (main.dart). */
    private fun run(context: Context, done: () -> Unit) {
        val app = context.applicationContext
        Handler(Looper.getMainLooper()).post {
            if (running) {
                done()
                return@post
            }
            running = true
            var engine: FlutterEngine? = null
            var finished = false
            val handler = Handler(Looper.getMainLooper())
            fun finish() {
                if (finished) return
                finished = true
                handler.removeCallbacksAndMessages(null)
                try {
                    engine?.destroy()
                } catch (e: Exception) {
                }
                engine = null
                running = false
                done()
            }
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(app)
                loader.ensureInitializationComplete(app, null)
                // Only the plugins the planning needs (no audio, no UI).
                val e = FlutterEngine(app, null, false)
                e.plugins.add(SharedPreferencesPlugin())
                e.plugins.add(FlutterLocalNotificationsPlugin())
                registerChannels(app, e.dartExecutor.binaryMessenger) { finish() }
                engine = e
                handler.postDelayed({ finish() }, TIMEOUT_MS)
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "backgroundTopUp")
                )
            } catch (ex: Exception) {
                finish()
            }
        }
    }

    /** The channels the planning uses, for the background engine. */
    private fun registerChannels(context: Context, messenger: BinaryMessenger, onDone: () -> Unit) {
        MethodChannel(messenger, "ayah_reminder/reminder").setMethodCallHandler { call, result ->
            if (call.method == "schedule") {
                saveReminders(context, call)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(messenger, "ayah_reminder/azan").setMethodCallHandler { call, result ->
            if (call.method == "schedule") {
                saveAzan(context, call)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(messenger, "ayah_reminder/system").setMethodCallHandler { call, result ->
            if (call.method == "canScheduleExactAlarms") {
                result.success(canScheduleExact(context))
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(messenger, "ayah_reminder/planner").setMethodCallHandler { call, result ->
            handlePlanner(context, call, result, onDone)
        }
    }

    /** "planned" (save refreshAt) and "done" (the background run is over). */
    fun handlePlanner(context: Context, call: MethodCall, result: MethodChannel.Result, onDone: () -> Unit) {
        when (call.method) {
            "planned" -> {
                planned(
                    context,
                    call.argument<Number>("refreshAt")?.toLong() ?: 0L,
                    call.argument<Number>("until")?.toLong() ?: 0L,
                )
                result.success(true)
            }
            "done" -> {
                result.success(true)
                onDone()
            }
            else -> result.notImplemented()
        }
    }

    fun saveReminders(context: Context, call: MethodCall) {
        ReminderStore.save(
            context,
            call.argument<String>("events") ?: "[]",
            call.argument<String>("sound") ?: "chime",
            call.argument<Boolean>("vibrate") ?: true,
        )
        ReminderScheduler.scheduleNext(context)
    }

    fun saveAzan(context: Context, call: MethodCall) {
        AzanStore.save(
            context,
            call.argument<String>("events") ?: "[]",
            call.argument<Boolean>("inSilent") ?: true,
            call.argument<Boolean>("fullScreen") ?: true,
            call.argument<Double>("volume") ?: 1.0,
            call.argument<Boolean>("vibrate") ?: true,
        )
        AzanScheduler.scheduleNext(context)
    }

    fun canScheduleExact(context: Context): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms()
}

/** The daily check: tops up the plan if needed, then sets the next check. */
class PlannerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Planner.scheduleDaily(context)
        val pending = goAsync()
        Planner.maybeRun(context, false) { pending.finish() }
    }
}
