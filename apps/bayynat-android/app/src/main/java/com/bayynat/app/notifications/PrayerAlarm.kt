package com.bayynat.app.notifications

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.bayynat.app.MainActivity
import com.bayynat.app.R
import com.batoulapps.adhan.CalculationMethod
import com.bayynat.app.core.PrayerCalculator

object PrayerNotifications {
    const val CHANNEL_ID = "bayynat_prayer_alerts"
    private const val CHANNEL_NAME = "تنبيهات الصلاة"
    private const val PREFS = "bayynat_prayer_sound"
    private const val CHANNEL_KEY = "channel_id"

    fun createChannel(context: Context) = createChannel(context, CHANNEL_ID, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))

    fun setCustomSound(context: Context, soundUri: Uri) {
        val customId = "bayynat_prayer_" + soundUri.toString().hashCode().toUInt().toString(16)
        createChannel(context, customId, soundUri)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(CHANNEL_KEY, customId).apply()
    }

    private fun activeChannelId(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(CHANNEL_KEY, CHANNEL_ID) ?: CHANNEL_ID

    private fun createChannel(context: Context, channelId: String, sound: Uri?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(channelId) != null) return
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(channelId, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
            description = "إشعارات أوقات الصلاة التي يفعّلها المستخدم"
            setSound(sound, attributes)
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    fun show(context: Context, prayerName: String) {
        createChannel(context)
        val openIntent = PendingIntent.getActivity(
            context, 7001, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, activeChannelId(context))
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("حان وقت صلاة $prayerName")
            .setContentText("حيّ على الصلاة")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(openIntent)
            .build()
        runCatching {
            NotificationManagerCompat.from(context).notify(prayerName.hashCode(), notification)
        }
    }
}

object PrayerAlarmScheduler {
    const val EXTRA_PRAYER_NAME = "extra_prayer_name"
    private const val REQUEST_CODE = 7002
    private const val PREFS = "bayynat_prayer_alarm"
    private const val KEY_TIME = "trigger_time"
    private const val KEY_NAME = "prayer_name"

    fun canScheduleExact(context: Context): Boolean {
        val manager = context.getSystemService(AlarmManager::class.java)
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = android.net.Uri.parse("package:" + context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    fun schedule(context: Context, triggerAtMillis: Long, prayerName: String) {
        require(triggerAtMillis > System.currentTimeMillis()) { "Alarm time must be in the future" }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_TIME, triggerAtMillis)
            .putString(KEY_NAME, prayerName)
            .apply()
        val manager = context.getSystemService(AlarmManager::class.java)
        val intent = Intent(context, PrayerAlarmReceiver::class.java)
            .putExtra(EXTRA_PRAYER_NAME, prayerName)
        val pending = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        } else {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    fun scheduleNextFromSavedLocation(context: Context) {
        val prefs = context.getSharedPreferences("bayynat_prayer_location", Context.MODE_PRIVATE)
        val latitude = prefs.getString("latitude", null)?.toDoubleOrNull()
        val longitude = prefs.getString("longitude", null)?.toDoubleOrNull()
        if (latitude == null || longitude == null) return
        val methodName = prefs.getString("method", CalculationMethod.MUSLIM_WORLD_LEAGUE.name)
        val method = runCatching { CalculationMethod.valueOf(methodName ?: "") }
            .getOrDefault(CalculationMethod.MUSLIM_WORLD_LEAGUE)
        runCatching {
            val next = PrayerCalculator.calculate(latitude, longitude, method = method).nextPrayer()
            schedule(context, next.second.time, next.first)
        }
    }

    fun cancel(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        val intent = Intent(context, PrayerAlarmReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context, REQUEST_CODE, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }
}

class PrayerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED && intent.action != Intent.ACTION_TIME_CHANGED && intent.action != Intent.ACTION_TIMEZONE_CHANGED) return
        PrayerAlarmScheduler.scheduleNextFromSavedLocation(context)
        val prefs = context.getSharedPreferences("bayynat_prayer_alarm", Context.MODE_PRIVATE)
        val trigger = prefs.getLong("trigger_time", 0L)
        val name = prefs.getString("prayer_name", null)
        if (trigger > System.currentTimeMillis() && name != null) {
            PrayerAlarmScheduler.schedule(context, trigger, name)
        }
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val name = intent.getStringExtra(PrayerAlarmScheduler.EXTRA_PRAYER_NAME) ?: "الصلاة"
        PrayerNotifications.show(context, name)
        PrayerAlarmScheduler.scheduleNextFromSavedLocation(context)
    }
}
