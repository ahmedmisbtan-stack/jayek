package com.bayynat.app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.state.PreferencesGlanceStateDefinition
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.glance.unit.dp
import androidx.glance.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.height
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.TextAlign
import com.bayynat.app.MainActivity
import android.graphics.Color

private val nextPrayerKey = stringPreferencesKey("widget_next_prayer")
private val nextTimeKey = stringPreferencesKey("widget_next_time")
private val locationKey = stringPreferencesKey("widget_location")

class PrayerWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    @Composable
    override fun Content() {
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

class PrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = PrayerWidget()
}

object PrayerWidgetUpdater {
    suspend fun update(context: Context, prayer: String, time: String, location: String) {
        val manager = GlanceAppWidgetManager(context)
        val ids = manager.getGlanceIds(PrayerWidget::class.java)
        ids.forEach { id ->
            updateAppWidgetState(context, PreferencesGlanceStateDefinition, id) { prefs ->
                prefs[nextPrayerKey] = prayer
                prefs[nextTimeKey] = time
                prefs[locationKey] = location
            }
            PrayerWidget().update(context, id)
        }
    }
}
