package com.bayynat.app.core

import android.icu.text.DateFormat
import android.icu.util.IslamicCalendar
import java.util.Date
import java.util.Locale

data class HijriDateLabel(val day: String, val month: String, val year: String, val full: String)

object HijriDateProvider {
    fun today(date: Date = Date(), locale: Locale = Locale("ar")): HijriDateLabel {
        val calendar = IslamicCalendar().apply { time = date }
        val day = calendar.get(IslamicCalendar.DAY_OF_MONTH).toString()
        val month = calendar.getDisplayName(IslamicCalendar.MONTH, IslamicCalendar.LONG, locale)
            ?: calendar.get(IslamicCalendar.MONTH).toString()
        val year = calendar.get(IslamicCalendar.YEAR).toString()
        val formatter = DateFormat.getDateInstance(DateFormat.LONG, locale).apply {
            calendar = IslamicCalendar().apply { time = date }
        }
        return HijriDateLabel(day, month, year, formatter.format(date))
    }
}
