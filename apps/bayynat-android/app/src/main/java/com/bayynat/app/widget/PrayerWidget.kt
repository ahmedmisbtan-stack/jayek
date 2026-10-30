package com.bayynat.app.widget

import android.content.Context
import android.graphics.Color
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.provideContent
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.toMutablePreferences
import com.bayynat.app.MainActivity

private val nextPrayerKey = stringPreferencesKey("widget_next_prayer")
private val nextTimeKey = stringPreferencesKey("widget_next_time")
private val locationKey = stringPreferencesKey("widget_location")

class PrayerWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<Preferences>()
            val prayer = state[nextPrayerKey] ?: "افتح التطبيق لتحديث المواقيت"
            val time = state[nextTimeKey] ?: "--:--"
            val location = state[locationKey] ?: "بيّنات"
            Column(
                modifier = GlanceModifier.fillMaxSize()
                    .background(ColorProvider(Color.rgb(8, 38, 76)))
                    .padding(14.dp)
                    .clickable(actionStartActivity<MainActivity>()),
                verticalAlignment = Alignment.Vertical.CenterVertically,
                horizontalAlignment = Alignment.Horizontal.Start
            ) {
                Text("بيّنات", style = TextStyle(color = ColorProvider(Color.rgb(217, 154, 50)), fontSize = 13.sp, fontWeight = FontWeight.Bold))
                Spacer(GlanceModifier.height(5.dp))
                Text("الصلاة القادمة", style = TextStyle(color = ColorProvider(Color.WHITE), fontSize = 12.sp))
                Row(verticalAlignment = Alignment.Vertical.CenterVertically) {
                    Text(prayer, style = TextStyle(color = ColorProvider(Color.WHITE), fontSize = 20.sp, fontWeight = FontWeight.Bold))
                    Spacer(GlanceModifier.width(10.dp))
                    Text(time, style = TextStyle(color = ColorProvider(Color.rgb(217, 154, 50)), fontSize = 22.sp, fontWeight = FontWeight.Bold))
                }
                Text(location, style = TextStyle(color = ColorProvider(Color.LTGRAY), fontSize = 10.sp))
            }
        }
    }
}

class PrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PrayerWidget()
}

object PrayerWidgetUpdater {
    suspend fun update(context: Context, prayer: String, time: String, location: String) {
        val manager = GlanceAppWidgetManager(context)
        manager.getGlanceIds(PrayerWidget::class.java).forEach { id ->
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs.toMutablePreferences().apply {
                    this[nextPrayerKey] = prayer
                    this[nextTimeKey] = time
                    this[locationKey] = location
                }
            }
            PrayerWidget().update(context, id)
        }
    }
}
