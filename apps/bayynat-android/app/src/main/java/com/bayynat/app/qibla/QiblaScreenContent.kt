package com.bayynat.app.qibla

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.bayynat.app.core.CompassHeadingProvider
import com.bayynat.app.core.QiblaCalculator
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlin.math.roundToInt

@Composable
fun QiblaScreenContent() {
    val context = LocalContext.current
    val fused = remember(context) { LocationServices.getFusedLocationProviderClient(context) }
    val compass = remember(context) { CompassHeadingProvider(context) }
    val heading by compass.heading.collectAsState()
    var latitude by remember { mutableStateOf<Double?>(null) }
    var longitude by remember { mutableStateOf<Double?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    DisposableEffect(compass) {
        compass.start()
        onDispose { compass.stop() }
    }

    fun locate() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!granted) return
        try {
            fused.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token)
                .addOnSuccessListener { result ->
                    if (result != null) {
                        latitude = result.latitude
                        longitude = result.longitude
                        error = null
                    } else error = "لم يصل موقع الجهاز بعد؛ حاول مجددًا."
                }
                .addOnFailureListener { error = "تعذّر تحديد الموقع." }
        } catch (_: SecurityException) {
            error = "إذن الموقع غير متاح."
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        if (result.values.any { it }) locate()
        else error = "اسمح بالموقع لحساب اتجاه القبلة، أو أعد المحاولة لاحقًا."
    }

    val bearing = if (latitude != null && longitude != null) {
        runCatching { QiblaCalculator.bearing(latitude!!, longitude!!) }.getOrNull()
    } else null
    val declination = if (latitude != null && longitude != null) GeomagneticField(latitude!!.toFloat(), longitude!!.toFloat(), 0f, System.currentTimeMillis()).declination.toDouble() else 0.0
    val trueHeading = if (heading != null) (heading!! + declination + 360.0) % 360.0 else null
    val relative = if (bearing != null && trueHeading != null) (bearing - trueHeading + 360.0) % 360.0 else null

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("اتجاه القبلة", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Button(onClick = {
            val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (fine || coarse) locate()
            else permissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        }) { Text("تحديد موقعي") }

        if (bearing != null && relative != null) {
            Canvas(modifier = Modifier.size(240.dp)) {
                val center = Offset(size.width / 2f, size.height / 2f)
                val radius = size.minDimension * .42f
                drawCircle(color = Color(0xFF176B55), radius = radius, center = center, style = androidx.compose.ui.graphics.drawscope.Stroke(width = 5f))
                drawCircle(color = Color(0xFFD99A32), radius = 8f, center = center)
                rotate(relative.toFloat(), pivot = center) {
                    drawLine(Color(0xFFD99A32), Offset(center.x, center.y + radius * .68f), Offset(center.x, center.y - radius * .82f), strokeWidth = 10f, cap = StrokeCap.Round)
                    drawCircle(Color(0xFFD99A32), radius = 11f, center = Offset(center.x, center.y - radius * .82f))
                }
            }
            Text("القبلة: ${bearing.roundToInt()}° من الشمال الحقيقي", fontWeight = FontWeight.Bold)
            Text("حرّك الهاتف حتى يشير السهم إلى القبلة.")
        } else {
            Text(if (!compass.isAvailable) "حساس البوصلة غير متوفر في هذا الجهاز." else "بانتظار تحديد الموقع وقراءة البوصلة.")
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Text("لتحسين الدقة، أبعد الهاتف عن المعادن والمغناطيس وحرّكه على شكل 8 لمعايرة البوصلة.", style = MaterialTheme.typography.bodySmall)
    }
}
