package com.bayynat.app.core

import com.batoulapps.adhan.CalculationMethod
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class PrayerCalculatorTest {
    @Test fun egyptianMethodReturnsOrderedTimes() {
        val date = Calendar.getInstance().apply {
            set(2026, Calendar.JANUARY, 15, 12, 0, 0)
        }.time
        val times = PrayerCalculator.calculate(
            latitude = 30.0444,
            longitude = 31.2357,
            date = date,
            method = CalculationMethod.EGYPTIAN
        )
        assertTrue(times.fajr.before(times.sunrise))
        assertTrue(times.sunrise.before(times.dhuhr))
        assertTrue(times.dhuhr.before(times.asr))
        assertTrue(times.asr.before(times.maghrib))
        assertTrue(times.maghrib.before(times.isha))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidCoordinates() {
        PrayerCalculator.calculate(120.0, 31.0)
    }
}
