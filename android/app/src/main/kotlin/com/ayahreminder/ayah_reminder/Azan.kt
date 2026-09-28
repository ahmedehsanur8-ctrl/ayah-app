package com.ayahreminder.ayah_reminder

import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full azan at prayer times.
 *
 * The Flutter side calculates the prayer times and saves the next 30 days here
 * ([AzanStore]). Only the next one is set as an alarm; when it rings, the next
 * one is set. The alarm starts [AzanService] (a foreground service of type
 * mediaPlayback) which plays the bundled azan from start to end on the alarm
 * stream, with a "থামান" notification and an optional full-screen page
 * ([AzanActivity]). [AzanBootReceiver] sets the alarm again after a restart.
 */
object AzanStore {
    private const val PREFS = "azan_schedule"

    fun save(context: Context, events: String, inSilent: Boolean, fullScreen: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("events", events)
            .putBoolean("inSilent", inSilent)
            .putBoolean("fullScreen", fullScreen)
            .apply()
    }

    fun events(context: Context): JSONArray = try {
        JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("events", "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    fun inSilent(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("inSilent", true)

    fun fullScreen(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("fullScreen", true)
}

object AzanScheduler {
    private const val REQUEST = 7001

    private fun alarmIntent(context: Context, e: JSONObject?): PendingIntent {
        val i = Intent(context, AzanAlarmReceiver::class.java).setAction("com.ayahreminder.AZAN_ALARM")
        if (e != null) {
            i.putExtra("key", e.optString("key"))
                .putExtra("name", e.optString("name"))
                .putExtra("mode", e.optString("mode"))
                .putExtra("fajr", e.optBoolean("fajr"))
                .putExtra("time", e.optLong("t"))
        }
        return PendingIntent.getBroadcast(
            context, REQUEST, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Sets the alarm for the first saved azan after [after] (ms), or cancels it. */
    fun scheduleNext(context: Context, after: Long = System.currentTimeMillis()) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(context, null))
        val events = AzanStore.events(context)
        var next: JSONObject? = null
        for (i in 0 until events.length()) {
            val e = events.getJSONObject(i)
            if (e.optLong("t") > after && (next == null || e.optLong("t") < next.optLong("t"))) next = e
        }
        val e = next ?: return
        val pi = alarmIntent(context, e)
        val t = e.optLong("t")
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact && e.optString("mode") == "azan") {
                // An alarm clock is the most reliable way to wake the phone on time,
                // also on phones that stop background work (Oppo, Xiaomi, …).
                val show = PendingIntent.getActivity(
                    context, REQUEST + 1, Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(t, show), pi)
            } else if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
            }
        } catch (ex: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, t, pi)
        }
    }
}

/** Rings at a prayer time: plays the azan or shows a notification, then sets the next alarm. */
class AzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val time = intent.getLongExtra("time", 0L)
        val name = intent.getStringExtra("name") ?: ""
        val late = System.currentTimeMillis() - time
        // Don't start an azan that is more than 15 minutes late (phone was off, etc.).
        if (time > 0 && late < 15 * 60 * 1000L) {
            if (intent.getStringExtra("mode") == "azan") {
                AzanService.start(context, name, intent.getBooleanExtra("fajr", false), time)
            } else {
                AzanNotifications.showPrayerTime(context, name, time)
            }
        }
        AzanScheduler.scheduleNext(context, maxOf(time, System.currentTimeMillis()))
    }
}

/** Sets the next azan alarm again after a restart, an app update or a clock change. */
class AzanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AzanScheduler.scheduleNext(context)
    }
}

object AzanNotifications {
    const val PLAYING_CHANNEL = "azan_playing"
    const val NOTIFY_CHANNEL = "azan_notify"
    const val PLAYING_ID = 7100
    private const val NOTIFY_ID = 7101

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val playing = NotificationChannel(PLAYING_CHANNEL, "আজান চলছে", NotificationManager.IMPORTANCE_HIGH)
        playing.description = "আজান বাজার সময় দেখায়, থামানোর বোতামসহ"
        playing.setSound(null, null) // the service plays the azan itself
        playing.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        nm.createNotificationChannel(playing)
        val notify = NotificationChannel(NOTIFY_CHANNEL, "নামাজের সময় (শুধু নোটিফিকেশন)", NotificationManager.IMPORTANCE_HIGH)
        notify.description = "আজান ছাড়া, শুধু নামাজের সময় জানায়"
        notify.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        nm.createNotificationChannel(notify)
    }

    @Suppress("DEPRECATION")
    fun builder(context: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)

    fun clock(time: Long): String {
        val t = SimpleDateFormat("h:mm", Locale.US).format(Date(if (time > 0) time else System.currentTimeMillis()))
        val bn = "০১২৩৪৫৬৭৮৯"
        return t.map { if (it in '0'..'9') bn[it - '0'] else it }.joinToString("")
    }

    /** "শুধু নোটিফিকেশন" mode. */
    fun showPrayerTime(context: Context, name: String, time: Long) {
        ensureChannels(context)
        val open = PendingIntent.getActivity(
            context, 7102, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = builder(context, NOTIFY_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("${genitive(name)} সময় হয়েছে")
            .setContentText("$name · ${clock(time)}")
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setColor(Color.parseColor("#14553F"))
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            nm.notify(NOTIFY_ID, n)
        } catch (e: SecurityException) {
            // Notifications not allowed.
        }
    }

    fun genitive(name: String) = if (name == "ইশা") "ইশার" else "${name}ের"
}

/** Plays the full azan in the foreground, on the alarm stream. */
class AzanService : Service() {
    companion object {
        private const val ACTION_PLAY = "com.ayahreminder.AZAN_PLAY"
        private const val ACTION_STOP = "com.ayahreminder.AZAN_STOP"

        @Volatile
        var isPlaying = false
            private set

        /** Called when the azan stops (so the full-screen page can close). */
        var onStopped: (() -> Unit)? = null

        fun start(context: Context, name: String, fajr: Boolean, time: Long) {
            val i = Intent(context, AzanService::class.java).setAction(ACTION_PLAY)
                .putExtra("name", name).putExtra("fajr", fajr).putExtra("time", time)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
        }

        fun stop(context: Context) {
            if (!isPlaying) return
            context.startService(Intent(context, AzanService::class.java).setAction(ACTION_STOP))
        }

        fun stopIntent(context: Context): PendingIntent = PendingIntent.getService(
            context, 7103, Intent(context, AzanService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private var player: MediaPlayer? = null
    private var session: MediaSession? = null
    private var focus: AudioFocusRequest? = null
    private var volumeReceiver: BroadcastReceiver? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish()
            return START_NOT_STICKY
        }
        val name = intent?.getStringExtra("name") ?: ""
        val fajr = intent?.getBooleanExtra("fajr", false) ?: false
        val time = intent?.getLongExtra("time", 0L) ?: 0L
        AzanNotifications.ensureChannels(this)
        val notification = buildNotification(name, time)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(AzanNotifications.PLAYING_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(AzanNotifications.PLAYING_ID, notification)
        }
        releasePlayer()

        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val silent = am.ringerMode != AudioManager.RINGER_MODE_NORMAL
        if (silent && !AzanStore.inSilent(this)) {
            // The user chose to keep silent mode silent: just tell the time.
            AzanNotifications.showPrayerTime(this, name, time)
            finish()
            return START_NOT_STICKY
        }
        if (!play(fajr, am)) {
            AzanNotifications.showPrayerTime(this, name, time)
            finish()
            return START_NOT_STICKY
        }
        isPlaying = true
        startVolumeKeyStop()
        if (AzanStore.fullScreen(this) && canShowFullScreen()) openFullScreenPage(name, time)
        return START_NOT_STICKY
    }

    private fun rawId(fajr: Boolean): Int {
        if (fajr) {
            val f = resources.getIdentifier("azan_fajr", "raw", packageName)
            if (f != 0) return f
        }
        return resources.getIdentifier("azan", "raw", packageName)
    }

    private fun play(fajr: Boolean, am: AudioManager): Boolean {
        val id = rawId(fajr)
        if (id == 0) return false
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        return try {
            val p = MediaPlayer()
            p.setAudioAttributes(attrs)
            p.setDataSource(this, Uri.parse("android.resource://$packageName/$id"))
            p.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            p.setOnCompletionListener { finish() }
            p.setOnErrorListener { _, _, _ -> finish(); true }
            p.prepare()
            if (Build.VERSION.SDK_INT >= 26) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attrs).build()
                focus = req
                am.requestAudioFocus(req)
            }
            p.start()
            player = p
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Pressing a volume key stops the azan. */
    private fun startVolumeKeyStop() {
        // While this session plays with "remote" volume, volume keys come here
        // (also when the screen is locked) instead of changing the volume.
        val s = MediaSession(this, "azan")
        s.setPlaybackToRemote(object : VolumeProvider(VolumeProvider.VOLUME_CONTROL_RELATIVE, 1, 1) {
            override fun onAdjustVolume(direction: Int) {
                finish()
            }
        })
        s.setPlaybackState(
            PlaybackState.Builder().setState(PlaybackState.STATE_PLAYING, 0, 1f).build()
        )
        s.isActive = true
        session = s
        // Backup: if the phone still changes a volume, stop too.
        val startedAt = System.currentTimeMillis()
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                // Ignore changes right at the start (some phones send one when playback begins).
                if (System.currentTimeMillis() - startedAt > 1500) finish()
            }
        }
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
        else registerReceiver(r, filter)
        volumeReceiver = r
    }

    private fun canShowFullScreen(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    private fun pageIntent(name: String, time: Long): Intent =
        Intent(this, AzanActivity::class.java)
            .putExtra("name", name).putExtra("time", time)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)

    private fun openFullScreenPage(name: String, time: Long) {
        try {
            startActivity(pageIntent(name, time))
        } catch (e: Exception) {
            // Not allowed from the background here; the notification's full-screen intent covers it.
        }
    }

    private fun buildNotification(name: String, time: Long): Notification {
        val page = PendingIntent.getActivity(
            this, 7104, pageIntent(name, time),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stop = stopIntent(this)
        val b = AzanNotifications.builder(this, AzanNotifications.PLAYING_CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(name.ifEmpty { "আজান" })
            .setContentText("আজান চলছে · ${AzanNotifications.clock(time)}")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(Color.parseColor("#14553F"))
            .setOngoing(true)
            .setContentIntent(page)
            .setDeleteIntent(stop)
            .addAction(Notification.Action.Builder(null, "থামান", stop).build())
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_MAX)
        if (AzanStore.fullScreen(this)) b.setFullScreenIntent(page, true)
        return b.build()
    }

    private fun releasePlayer() {
        try {
            player?.stop()
        } catch (e: Exception) {
        }
        player?.release()
        player = null
    }

    private fun finish() {
        isPlaying = false
        releasePlayer()
        session?.release()
        session = null
        volumeReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
            }
        }
        volumeReceiver = null
        if (Build.VERSION.SDK_INT >= 26) {
            focus?.let { (getSystemService(Context.AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it) }
        }
        focus = null
        onStopped?.invoke()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (isPlaying) finish()
        super.onDestroy()
    }
}

/** Full-screen azan page over the lock screen: prayer name, time, big stop button. */
class AzanActivity : Activity() {
    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, resources.displayMetrics)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (!AzanService.isPlaying) {
            finish()
            return
        }
        val name = intent.getStringExtra("name") ?: ""
        val time = intent.getLongExtra("time", 0L)
        val gold = Color.parseColor("#F1DDA8")
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#0E3B2C"))
            setPadding(dp(24f).toInt(), dp(24f).toInt(), dp(24f).toInt(), dp(24f).toInt())
        }
        fun text(s: String, size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
            text = s
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
            if (bold) setTypeface(typeface, Typeface.BOLD)
        }
        root.addView(text("আজান চলছে", 18f, gold))
        root.addView(text(name, 46f, Color.WHITE, true))
        root.addView(text(AzanNotifications.clock(time), 22f, Color.WHITE))
        val stop = Button(this).apply {
            text = "থামান"
            textSize = 24f
            setTextColor(Color.parseColor("#0E3B2C"))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(gold)
            }
            setOnClickListener {
                AzanService.stop(this@AzanActivity)
                finish()
            }
        }
        val size = dp(150f).toInt()
        root.addView(stop, LinearLayout.LayoutParams(size, size).apply { topMargin = dp(48f).toInt() })
        root.addView(text("ভলিউম বোতাম চাপলেও থামবে", 14f, Color.parseColor("#CCFFFFFF")).apply {
            setPadding(0, dp(20f).toInt(), 0, 0)
        })
        setContentView(root)
        AzanService.onStopped = { runOnUiThread { finish() } }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            AzanService.stop(this)
            finish()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        AzanService.onStopped = null
        super.onDestroy()
    }
}
