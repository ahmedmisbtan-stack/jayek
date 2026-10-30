package com.bayynat.app.core

import android.icu.util.IslamicCalendar
import java.util.Date

data class HijriDateLabel(val day: String, val month: String, val year: String, val full: String)

object HijriDateProvider {
    private val monthNames = listOf(
        "محرّم", "صفر", "ربيع الأول", "ربيع الآخر",
        "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
        "رمضان", "شوّال", "ذو القعدة", "ذو الحجة"
    )

    fun today(date: Date = Date()): HijriDateLabel {
        val calendar = IslamicCalendar().apply { time = date }
        val day = calendar.get(IslamicCalendar.DAY_OF_MONTH).toString()
        val monthIndex = calendar.get(IslamicCalendar.MONTH)
        val month = monthNames.getOrElse(monthIndex) { "الشهر ${monthIndex + 1}" }
        val year = calendar.get(IslamicCalendar.YEAR).toString()
        return HijriDateLabel(day, month, year, "$day $month $year هـ")
    }
}
