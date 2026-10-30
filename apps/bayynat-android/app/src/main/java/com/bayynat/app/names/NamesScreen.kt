package com.bayynat.app.names

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun NamesScreenContent() {
    val context = LocalContext.current
    val examples = listOf(
        "الغنيّ", "القادر", "العليم", "الحكيم", "الرحيم",
        "الرحمن", "العزيز", "الجبّار", "الجميل", "المتكبّر", "المتعالي"
    )
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Text("أسماء الله الحسنى", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("منهج بيّنات في عرض الأسماء", fontWeight = FontWeight.SemiBold)
                    Text("تذكر مادة منشورة في موقع بيّنات أن الأسماء الحسنى التي نوّه بها القرآن تبلغ 127 اسمًا؛ لذلك لا نفترض حصرها في 99 اسمًا. هذه أمثلة وردت في المادة نفسها، وليست قائمة نهائية.")
                }
            }
        }
        items(examples) { name ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Text(name, modifier = Modifier.fillMaxWidth().padding(14.dp), style = MaterialTheme.typography.titleMedium)
            }
        }
        item {
            Button(
                onClick = {
                    context.startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("https://www.bayynat.org.lb/article/%D8%B2%D8%A7%D8%AF-%D8%A7%D9%84%D8%B1%D9%88%D8%AD/30120/%D8%A3%D8%B3%D9%85%D8%A7%D8%A1-%D8%A7%D9%84%D9%84%D9%87-%D8%A7%D9%84%D8%AA%D9%8A-%D9%85%D9%84%D8%A3%D8%AA-%D8%A3%D8%B1%D9%83%D8%A7%D9%86-%D9%83%D9%84%D9%91-%D8%B4%D9%8A%D8%A1/ar")
                        )
                    )
                },
                modifier = Modifier.fillMaxWidth()
            ) { Text("قراءة المادة الأصلية في موقع بيّنات") }
        }
    }
}
