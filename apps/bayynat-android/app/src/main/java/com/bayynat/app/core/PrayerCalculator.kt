package com.bayynat.app.core

import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.DateComponents
import com.batoulapps.adhan.PrayerTimes
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Calendar
import java.util.Locale

data class PrayerSchedule(
    val fajr: Date,
    val sunrise: Date,
    val dhuhr: Date,
    val asr: Date,
    val maghrib: Date,
    val isha: Date
) {
    fun nextPrayer(now: Date = Date()): Pair<String, Date> {
        val items = listOf("الفجر" to fajr, "الشروق" to sunrise, "الظهر" to dhuhr, "العصر" to asr, "المغرب" to maghrib, "العشاء" to isha)
        return items.firstOrNull { it.second.after(now) } ?: (\n            "الفجر" to Calendar.getInstance().apply { time = fajr; add(Calendar.DAY_OF_YEAR, 1) }.time\n        )
    }

    fun asRows(locale: Locale = Locale.getDefault()): List<Pair<String, String>> {
        val formatter = SimpleDateFormat("HH:mm", locale)
        return listOf(
            "الفجر" to formatter.format(fajr),
            "الشروق" to formatter.format(sunrise),
            "الظهر" to formatter.format(dhuhr),
            "العصر" to formatter.format(asr),
            "المغرب" to formatter.format(maghrib),
            "العشاء" to formatter.format(isha)
        )
    }
}

/** Offline calculation; coordinates and method must be supplied, never guessed. */
object PrayerCalculator {
    fun calculate(
        latitude: Double,
        longitude: Double,
        date: Date = Date(),
        method: CalculationMethod = CalculationMethod.MUSLIM_WORLD_LEAGUE
    ): PrayerSchedule {
        require(latitude in -90.0..90.0) { "Latitude is outside the valid range" }
        require(longitude in -180.0..180.0) { "Longitude is outside the valid range" }
        val result = PrayerTimes(
            Coordinates(latitude, longitude),
            DateComponents.from(date),
            method.parameters
        )
        return PrayerSchedule(result.fajr, result.sunrise, result.dhuhr, result.asr, result.maghrib, result.isha)
    }
}
