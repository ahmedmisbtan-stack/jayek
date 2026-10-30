package com.bayynat.app.widget

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.batoulapps.adhan.CalculationMethod
import com.bayynat.app.core.PrayerCalculator
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

class PrayerWidgetRefreshWorker(
    context: Context,
    parameters: WorkerParameters
) : CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences("bayynat_prayer_location", Context.MODE_PRIVATE)
        val latitude = prefs.getString("latitude", null)?.toDoubleOrNull() ?: return Result.success()
        val longitude = prefs.getString("longitude", null)?.toDoubleOrNull() ?: return Result.success()
        val methodName = prefs.getString("method", CalculationMethod.MUSLIM_WORLD_LEAGUE.name)
        val method = runCatching { CalculationMethod.valueOf(methodName ?: "") }
            .getOrDefault(CalculationMethod.MUSLIM_WORLD_LEAGUE)
        return runCatching {
            val next = PrayerCalculator.calculate(latitude, longitude, method = method).nextPrayer()
            val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(next.second)
            PrayerWidgetUpdater.update(applicationContext, next.first, time, prefs.getString("location", "موقعي") ?: "موقعي")
            Result.success()
        }.getOrElse { Result.retry() }
    }
}

object PrayerWidgetWork {
    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<PrayerWidgetRefreshWorker>(24, TimeUnit.HOURS).build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "bayynat_prayer_widget_refresh",
            ExistingPeriodicWorkPolicy.UPDATE,
            request
        )
    }
}
