package com.ayahreminder.ayah_reminder

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

/**
 * Alarm-style ayah / hadith reminders.
 *
 * Flutter saves the next 30 days of reminders here ([ReminderStore]). Only the
 * next one is set as an alarm clock; when it rings, [ReminderService] shows a
 * full-screen alarm notification, plays a gentle sound on the alarm stream with
 * vibration, and opens the reading page (over the lock screen, or over other apps
 * when "Display over other apps" is allowed). "আমি পড়েছি" / "১০ মিনিট পরে" on the
 * reading page stop the sound. [AzanBootReceiver] sets the alarm again after a restart.
 */
object ReminderStore {
    private const val PREFS = "reminder_schedule"

    fun save(context: Context, events: String, sound: String, vibrate: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("events", events)
            .putString("sound", sound)
            .putBoolean("vibrate", vibrate)
            .apply()
    }

    fun events(context: Context): JSONArray = try {
        JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("events", "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    /** 'chime', 'bell', 'phone', 'tilawat' (played by the app) or 'off'. */
    fun sound(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("sound", "chime") ?: "chime"

    fun vibrate(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("vibrate", true)
}

object ReminderScheduler {
    const val REQUEST_NEXT = 7201
    const val REQUEST_SNOOZE = 7202
    const val REQUEST_TEST = 7203

    fun eventIntent(context: Context, e: JSONObject?, request: Int): PendingIntent {
        val i = Intent(context, ReminderAlarmReceiver::class.java).setAction("com.ayahreminder.REMINDER_$request")
        if (e != null) i.putExtra("event", e.toString()).putExtra("request", request)
        return PendingIntent.getBroadcast(
            context, request, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun setAlarm(context: Context, t: Long, pi: PendingIntent) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact) {
                val show = PendingIntent.getActivity(
                    context, 7210, Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                // Alarm-clock alarms wake the phone on time, even in battery saving.
                am.setAlarmClock(AlarmManager.AlarmClockInfo(t, show), pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            }
        } catch (ex: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
        }
    }

    /** Sets the alarm for the first saved reminder after [after] (ms), or cancels it. */
    fun scheduleNext(context: Context, after: Long = System.currentTimeMillis()) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(eventIntent(context, null, REQUEST_NEXT))
        val events = ReminderStore.events(context)
        var next: JSONObject? = null
        for (i in 0 until events.length()) {
            val e = events.getJSONObject(i)
            if (e.optLong("t") > after && (next == null || e.optLong("t") < next.optLong("t"))) next = e
        }
        val e = next ?: return
        setAlarm(context, e.optLong("t"), eventIntent(context, e, REQUEST_NEXT))
    }

    /** One reminder at [t] (snooze or test), separate from the daily ones. */
    fun scheduleOnce(context: Context, e: JSONObject, t: Long, request: Int) {
        e.put("t", t)
        setAlarm(context, t, eventIntent(context, e, request))
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val raw = intent.getStringExtra("event") ?: return
        val e = try {
            JSONObject(raw)
        } catch (ex: Exception) {
            return
        }
        val request = intent.getIntExtra("request", ReminderScheduler.REQUEST_NEXT)
        val t = e.optLong("t")
        // Skip a reminder that is hours late (phone was off); the next one still comes.
        if (System.currentTimeMillis() - t < 2 * 60 * 60 * 1000L) ReminderService.start(context, e)
        if (request == ReminderScheduler.REQUEST_NEXT) {
            ReminderScheduler.scheduleNext(context, maxOf(t, System.currentTimeMillis()))
        }
    }
}

/** Shows the alarm notification, plays the gentle sound, opens the reading page. */
class ReminderService : Service() {
    companion object {
        const val CHANNEL = "reminder_alarm"
        const val NOTIFICATION_ID = 7300
        private const val ACTION_SHOW = "com.ayahreminder.REMINDER_SHOW"
        private const val ACTION_STOP_SOUND = "com.ayahreminder.REMINDER_STOP_SOUND"
        private const val ACTION_SNOOZE = "com.ayahreminder.REMINDER_SNOOZE"
        private const val MAX_SOUND_MS = 60_000L

        @Volatile
        var current: JSONObject? = null
            private set

        fun start(context: Context, e: JSONObject) {
            val i = Intent(context, ReminderService::class.java).setAction(ACTION_SHOW).putExtra("event", e.toString())
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
        }

        /** Stops the sound (the notification stays until the page is done). */
        fun stopSound(context: Context) {
            if (current == null) return
            context.startService(Intent(context, ReminderService::class.java).setAction(ACTION_STOP_SOUND))
        }

        fun snooze(context: Context) {
            context.startService(Intent(context, ReminderService::class.java).setAction(ACTION_SNOOZE))
        }

        /** The intent that opens the reading page for [e] in the Flutter app. */
        fun pageIntent(context: Context, e: JSONObject): Intent =
            Intent(context, MainActivity::class.java)
                .setAction("com.ayahreminder.OPEN_REMINDER")
                .putExtra("reminder_payload", e.optString("payload"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val c = NotificationChannel(CHANNEL, "আয়াত ও হাদিস রিমাইন্ডার (অ্যালার্ম)", NotificationManager.IMPORTANCE_HIGH)
            c.description = "সকাল ও রাতের রিমাইন্ডার, অ্যালার্মের মতো পুরো স্ক্রিনে"
            c.setSound(null, null) // the service plays the chosen sound itself
            c.enableVibration(false) // and vibrates itself
            c.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(c)
        }
    }

    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var soundStarted = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_SOUND -> {
                stopSoundAndDetach()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                current?.let {
                    ReminderScheduler.scheduleOnce(
                        this, JSONObject(it.toString()), System.currentTimeMillis() + 10 * 60 * 1000L,
                        ReminderScheduler.REQUEST_SNOOZE
                    )
                }
                stopSoundAndDetach()
                (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION_ID)
                current = null
                return START_NOT_STICKY
            }
        }
        val e = try {
            JSONObject(intent?.getStringExtra("event") ?: "{}")
        } catch (ex: Exception) {
            JSONObject()
        }
        current = e
        ensureChannel(this)
        val n = buildNotification(e)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
        openPage(e)
        playSound()
        return START_NOT_STICKY
    }

    private fun isLockedOrOff(): Boolean {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return km.isKeyguardLocked || !pm.isInteractive
    }

    /** Opens the reading page over the lock screen or over other apps when allowed. */
    private fun openPage(e: JSONObject) {
        val overlay = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this)
        if (!overlay && !isLockedOrOff()) return // the heads-up notification stays instead
        try {
            startActivity(pageIntent(this, e))
        } catch (ex: Exception) {
            // Not allowed now; the full-screen intent / notification covers it.
        }
    }

    private fun buildNotification(e: JSONObject): Notification {
        val open = PendingIntent.getActivity(
            this, 7301, pageIntent(this, e),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val snooze = PendingIntent.getService(
            this, 7302, Intent(this, ReminderService::class.java).setAction(ACTION_SNOOZE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = AzanNotifications.builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(e.optString("title"))
            .setContentText(e.optString("body"))
            .setStyle(Notification.BigTextStyle().bigText(e.optString("body")))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(Color.parseColor("#14553F"))
            .setOngoing(true)
            .setAutoCancel(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .addAction(Notification.Action.Builder(null, "পড়ুন", open).build())
            .addAction(Notification.Action.Builder(null, "১০ মিনিট পরে", snooze).build())
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_MAX)
        return b.build()
    }

    private fun soundUri(sound: String): Uri? = when (sound) {
        "chime", "bell" -> {
            val id = resources.getIdentifier(if (sound == "bell") "reminder_bell" else "reminder_chime", "raw", packageName)
            if (id != 0) Uri.parse("android.resource://$packageName/$id") else null
        }
        "phone" -> RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        else -> null
    }

    private fun playSound() {
        if (ReminderStore.vibrate(this)) vibrate()
        val uri = soundUri(ReminderStore.sound(this))
        if (uri == null) {
            // No sound (or the app plays the recitation): keep the notification only.
            handler.postDelayed({ stopSoundAndDetach() }, 3000)
            return
        }
        soundStarted = System.currentTimeMillis()
        playOnce(uri)
        handler.postDelayed({ stopSoundAndDetach() }, MAX_SOUND_MS)
    }

    /** Plays the sound, then again after a short pause, until stopped or 1 minute passes. */
    private fun playOnce(uri: Uri) {
        try {
            val p = MediaPlayer()
            p.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            p.setDataSource(this, uri)
            p.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            p.setOnCompletionListener {
                it.release()
                if (player === it) player = null
                if (System.currentTimeMillis() - soundStarted < MAX_SOUND_MS - 6000) {
                    handler.postDelayed({ if (current != null && soundStarted > 0) playOnce(uri) }, 4000)
                }
            }
            p.prepare()
            p.start()
            player = p
        } catch (e: Exception) {
            // No sound; the notification is still shown.
        }
    }

    private fun vibrate() {
        val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        val pattern = longArrayOf(0, 400, 250, 400)
        if (Build.VERSION.SDK_INT >= 26) {
            v.vibrate(
                VibrationEffect.createWaveform(pattern, -1),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
            )
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(pattern, -1)
        }
    }

    /** Stops the sound; the notification stays (until the reminder is read). */
    private fun stopSoundAndDetach() {
        soundStarted = 0
        handler.removeCallbacksAndMessages(null)
        try {
            player?.stop()
        } catch (e: Exception) {
        }
        player?.release()
        player = null
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        player?.release()
        player = null
        super.onDestroy()
    }
}
