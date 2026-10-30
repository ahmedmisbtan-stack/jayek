package com.bayynat.app.azkar

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

private data class DhikrItem(
    val text: String,
    val target: Int,
    val reference: String,
    val sourceUrl: String
)

@Composable
fun AzkarScreenContent() {
    val context = LocalContext.current
    val preferences = remember(context) { context.getSharedPreferences("bayynat_azkar_v1", 0) }
    var category by remember { mutableIntStateOf(0) }
    val daily = listOf(
        DhikrItem(
            "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
            100,
            "صحيح البخاري 6405",
            "https://sunnah.com/bukhari:6405"
        )
    )
    val afterPrayer = listOf(
        DhikrItem("سُبْحَانَ اللَّهِ", 33, "صحيح مسلم 597", "https://sunnah.com/muslim:597"),
        DhikrItem("الْحَمْدُ لِلَّهِ", 33, "صحيح مسلم 597", "https://sunnah.com/muslim:597"),
        DhikrItem("اللَّهُ أَكْبَرُ", 33, "صحيح مسلم 597", "https://sunnah.com/muslim:597"),
        DhikrItem(
            "لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
            1,
            "صحيح مسلم 597",
            "https://sunnah.com/muslim:597"
        )
    )
    val entries = if (category == 0) daily else afterPrayer
    var selected by remember(category) { mutableIntStateOf(0) }
    val item = entries[selected.coerceIn(entries.indices)]
    val key = "count_${category}_${selected}"
    var count by remember(key) { mutableIntStateOf(preferences.getInt(key, 0)) }

    Column(
        modifier = Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text("الأذكار والسبحة", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = category == 0, onClick = { category = 0 }, label = { Text("ذكر يومي") })
            FilterChip(selected = category == 1, onClick = { category = 1 }, label = { Text("بعد الصلاة") })
        }
        if (category == 1) {
            entries.forEachIndexed { index, entry ->
                FilterChip(
                    selected = selected == index,
                    onClick = {
                        selected = index
                        count = preferences.getInt("count_1_$index", 0)
                    },
                    label = { Text(entry.text.take(18) + if (entry.text.length > 18) "…" else "") }
                )
            }
        }
        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(item.text, textAlign = TextAlign.Center, style = MaterialTheme.typography.headlineSmall)
                Text("$count / ${item.target}", style = MaterialTheme.typography.displayMedium, color = MaterialTheme.colorScheme.primary)
                Button(
                    onClick = {
                        count = (count + 1).coerceAtMost(item.target)
                        preferences.edit().putInt(key, count).apply()
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("تسبيح") }
                OutlinedButton(
                    onClick = {
                        count = 0
                        preferences.edit().putInt(key, 0).apply()
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("إعادة العداد") }
                Text(item.reference, style = MaterialTheme.typography.labelMedium)
                OutlinedButton(
                    onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(item.sourceUrl))) }
                ) { Text("مصدر الذكر") }
            }
        }
        Text("يُحفظ عدّادك على الجهاز. الأذكار المعروضة هنا محدودة بما تم توثيق مرجعه، وسيُضاف باقي المحتوى بعد مراجعة مصادره.")
    }
}
