package com.bayynat.app.prayer

import android.Manifest
import android.os.Build
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.batoulapps.adhan.CalculationMethod
import com.bayynat.app.core.PrayerCalculator
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.bayynat.app.widget.PrayerWidgetUpdater
import com.bayynat.app.widget.PrayerWidgetWork
import com.bayynat.app.notifications.PrayerAlarmScheduler
import com.bayynat.app.notifications.PrayerNotifications
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Locale

@Composable
fun PrayerScreenContent() {
    val context = LocalContext.current
    val fused = remember(context) { LocationServices.getFusedLocationProviderClient(context) }
    val scope = rememberCoroutineScope()
    var latitude by remember { mutableStateOf("") }
    var longitude by remember { mutableStateOf("") }
    var locationLabel by remember { mutableStateOf("لم يتم تحديد الموقع") }
    var schedule by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    var error by remember { mutableStateOf<String?>(null) }
    var method by remember { mutableStateOf(CalculationMethod.MUSLIM_WORLD_LEAGUE) }
    var methodMenu by remember { mutableStateOf(false) }
    var nextPrayerName by remember { mutableStateOf<String?>(null) }
    var nextPrayerAt by remember { mutableStateOf<java.util.Date?>(null) }
    var alertsEnabled by remember { mutableStateOf(false) }

    fun readLocation() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!granted) return
        try {
            fused.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token)
                .addOnSuccessListener { location ->
                    if (location != null) {
                        latitude = location.latitude.toString()
                        longitude = location.longitude.toString()
                        locationLabel = "موقع الجهاز"
                        error = null
                    } else {
                        error = "تعذّر الحصول على موقع حديث. أدخل الإحداثيات يدويًا."
                    }
                }
                .addOnFailureListener { error = "تعذّر تحديد الموقع. يمكنك إدخال الإحداثيات يدويًا." }
        } catch (_: SecurityException) {
            error = "لم يُمنح إذن الموقع. يمكنك إدخال الإحداثيات يدويًا."
        }
    }


    fun scheduleNextAlert() {
        val time = nextPrayerAt?.time
        val name = nextPrayerName
        if (time == null || name == null) { error = "احسب المواقيت أولًا."; return }
        if (!PrayerAlarmScheduler.canScheduleExact(context)) {
            PrayerAlarmScheduler.openExactAlarmSettings(context)
            error = "فعّل المنبهات الدقيقة من إعدادات Android ثم اضغط التنبيه مجددًا."
            return
        }
        PrayerNotifications.createChannel(context)
        PrayerAlarmScheduler.schedule(context, time, name)
        alertsEnabled = true
        error = null
    }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) scheduleNextAlert() else error = "لم يتم منح إذن الإشعارات."
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        if (result.values.any { it }) readLocation()
        else error = "تم رفض إذن الموقع؛ يمكنك استخدام الإحداثيات اليدوية."
    }

    fun calculate() {
        val lat = latitude.toDoubleOrNull()
        val lon = longitude.toDoubleOrNull()
        if (lat == null || lon == null) {
            error = "أدخل خط العرض وخط الطول أو حدّد موقع الجهاز."
            return
        }
        runCatching { PrayerCalculator.calculate(lat, lon, method = method) }
            .onSuccess { result ->
                schedule = result.asRows()
                error = null
                val next = result.nextPrayer()
                nextPrayerName = next.first
                nextPrayerAt = next.second
                if (locationLabel == "لم يتم تحديد الموقع") locationLabel = "إحداثيات يدوية"
                context.getSharedPreferences("bayynat_prayer_location", 0).edit()
                    .putString("latitude", lat.toString())
                    .putString("longitude", lon.toString())
                    .putString("method", method.name)
                    .putString("location", locationLabel)
                    .apply()
                PrayerWidgetWork.schedule(context)
                alertsEnabled = false
                val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(next.second)
                scope.launch { PrayerWidgetUpdater.update(context, next.first, time, locationLabel) }
            }
            .onFailure { error = "تعذّر حساب المواقيت: تحقق من الإحداثيات وطريقة الحساب." }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("مواقيت الصلاة", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(locationLabel, color = MaterialTheme.colorScheme.secondary)
        Button(
            onClick = {
                val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
                if (fine || coarse) readLocation()
                else permissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("تحديد موقعي") }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = latitude, onValueChange = { latitude = it },
                label = { Text("خط العرض") }, modifier = Modifier.weight(1f), singleLine = true
            )
            OutlinedTextField(
                value = longitude, onValueChange = { longitude = it },
                label = { Text("خط الطول") }, modifier = Modifier.weight(1f), singleLine = true
            )
        }
        OutlinedButton(onClick = { methodMenu = true }, modifier = Modifier.fillMaxWidth()) {
            Text("طريقة الحساب: ${method.name}")
        }
        DropdownMenu(expanded = methodMenu, onDismissRequest = { methodMenu = false }) {
            listOf(
                CalculationMethod.MUSLIM_WORLD_LEAGUE,
                CalculationMethod.EGYPTIAN,
                CalculationMethod.KARACHI,
                CalculationMethod.UMM_AL_QURA,
                CalculationMethod.NORTH_AMERICA
            ).forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.name) },
                    onClick = { method = option; methodMenu = false }
                )
            }
        }
        Button(onClick = { calculate() }, modifier = Modifier.fillMaxWidth()) { Text("احسب المواقيت") }

        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }

        if (schedule.isNotEmpty()) {
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
                    schedule.forEach { (name, time) ->
                        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(name, fontWeight = FontWeight.Medium)
                            Text(time, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
            Text("هذه مواقيت محسوبة محليًا بالطريقة المختارة، وليست نقلًا مباشرًا عن خدمة بيّنات الرسمية.")
            OutlinedButton(
                onClick = {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else scheduleNextAlert()
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text(if (alertsEnabled) "تم ضبط تنبيه الصلاة القادمة" else "تنبيه الصلاة القادمة") }
            if (alertsEnabled) {
                OutlinedButton(onClick = { PrayerAlarmScheduler.cancel(context); alertsEnabled = false }) {
                    Text("إلغاء التنبيه")
                }
            }
        }

        OutlinedButton(
            onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.bayynat.org.lb/prayer-time")))
            },
            modifier = Modifier.fillMaxWidth()
        ) { Text("فتح خدمة المواقيت الرسمية من بيّنات") }

        Text(
            "تتيح الخدمة الرسمية اختيار اليوم أو الأسبوع أو الشهر أو السنة أو فترة زمنية، وتحديد الموقع أو البلد والمدينة، ثم تأكيد الاختيار.",
            style = MaterialTheme.typography.bodySmall
        )
    }
}
