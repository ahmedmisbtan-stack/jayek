package com.bayynat.app.notifications

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat

@Composable
fun PrayerAlertsScreenContent(onOpenPrayerTimes: () -> Unit) {
    val context = LocalContext.current
    var notificationGranted by remember {
        mutableStateOf(
            Build.VERSION.SDK_INT < 33 ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        )
    }
    var exactAlarmGranted by remember { mutableStateOf(PrayerAlarmScheduler.canScheduleExact(context)) }
    var message by remember { mutableStateOf<String?>(null) }
    var soundLabel by remember { mutableStateOf("نغمة النظام الافتراضية") }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                notificationGranted = Build.VERSION.SDK_INT < 33 ||
                    ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                exactAlarmGranted = PrayerAlarmScheduler.canScheduleExact(context)
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val soundPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            PrayerNotifications.setCustomSound(context, uri)
            soundLabel = uri.lastPathSegment ?: "ملف أذان مخصص"
            message = "تم اختيار ملف الصوت. قد تحتاج إلى السماح بصوته من إعدادات قناة الإشعار في Android."
        }
    }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        notificationGranted = granted
        message = if (granted) "تم منح إذن الإشعارات." else "لم يتم منح إذن الإشعارات."
        if (granted) PrayerNotifications.createChannel(context)
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text("التنبيهات والأذان", style = MaterialTheme.typography.headlineSmall)
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("إذن الإشعارات: " + if (notificationGranted) "مفعّل" else "غير مفعّل")
                Text("المنبهات الدقيقة: " + if (exactAlarmGranted) "مسموح بها" else "تحتاج إلى إذن من إعدادات النظام")
                Text("ستظهر التنبيهات على شاشة القفل وفق إعدادات الخصوصية في جهازك.")
            }
        }
        Button(
            onClick = {
                if (Build.VERSION.SDK_INT >= 33 && !notificationGranted) {
                    notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    notificationGranted = true
                    PrayerNotifications.createChannel(context)
                    message = "قناة تنبيهات الصلاة جاهزة."
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("تفعيل إشعارات الصلاة") }

        OutlinedButton(
            onClick = {
                PrayerAlarmScheduler.openExactAlarmSettings(context)
                exactAlarmGranted = PrayerAlarmScheduler.canScheduleExact(context)
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("إعداد إذن المنبهات الدقيقة") }

        OutlinedButton(
            onClick = { soundPicker.launch(arrayOf("audio/*")) },
            modifier = Modifier.fillMaxWidth()
        ) { Text("اختيار ملف صوت الأذان من الجهاز") }
        Text("الصوت المحدد: $soundLabel", style = MaterialTheme.typography.bodySmall)

        OutlinedButton(onClick = onOpenPrayerTimes, modifier = Modifier.fillMaxWidth()) {
            Text("حساب المواقيت وضبط تنبيه الصلاة القادمة")
        }

        OutlinedButton(
            onClick = {
                PrayerAlarmScheduler.cancel(context)
                message = "تم إلغاء التنبيه المجدول."
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("إيقاف تنبيه الصلاة المجدول") }

        OutlinedButton(
            onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.bayynat.org.lb/prayer-time")))
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("خدمة مواقيت الصلاة الرسمية") }

        message?.let { Text(it, color = MaterialTheme.colorScheme.primary) }
    }
}
