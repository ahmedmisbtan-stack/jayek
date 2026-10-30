package com.bayynat.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

private val Gold = Color(0xFFD99A32)
private val Green = Color(0xFF176B55)
private val Ivory = Color(0xFFFFF5E5)
private val Ink = Color(0xFF49351F)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { BayynatTheme { BayynatApp() } }
    }
}

@Composable
private fun BayynatTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Gold,
            secondary = Green,
            background = Ivory,
            surface = Color.White,
            onBackground = Ink,
            onSurface = Ink
        ),
        content = content
    )
}

private data class Destination(val title: String, val icon: ImageVector)

@Composable
private fun BayynatApp() {
    val destinations = listOf(
        Destination("الرئيسية", Icons.Default.Home),
        Destination("القرآن", Icons.Default.MenuBook),
        Destination("الصلاة", Icons.Default.AccessTime),
        Destination("الأذكار", Icons.Default.Favorite),
        Destination("المزيد", Icons.Default.GridView)
    )
    var selected by remember { mutableIntStateOf(0) }

    Scaffold(
        containerColor = Ivory,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text("بيّنات", color = Green, fontWeight = FontWeight.Bold)
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Ivory)
            )
        },
        bottomBar = {
            NavigationBar(containerColor = Color.White) {
                destinations.forEachIndexed { index, item ->
                    NavigationBarItem(
                        selected = selected == index,
                        onClick = { selected = index },
                        icon = { Icon(item.icon, contentDescription = item.title) },
                        label = { Text(item.title) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when (selected) {
                0 -> HomeScreen(onSelect = { selected = it })
                1 -> QuranScreen()
                2 -> PrayerScreen()
                3 -> AzkarScreen()
                else -> MoreScreen()
            }
        }
    }
}

@Composable
private fun HomeScreen(onSelect: (Int) -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Card(
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = Green)
        ) {
            Column(Modifier.fillMaxWidth().padding(22.dp)) {
                Text("السلام عليكم", color = Color.White, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(6.dp))
                Text("اجعل القرآن والذكر رفيق يومك", color = Color.White.copy(alpha = .9f))
                Spacer(Modifier.height(18.dp))
                Text("مواقيت الصلاة", color = Color.White.copy(alpha = .8f))
                Text("سيتم حسابها حسب موقعك بعد تفعيل إذن الموقع", color = Color.White, style = MaterialTheme.typography.bodyMedium)
            }
        }
        Text("أقسام بيّنات", style = MaterialTheme.typography.titleLarge, color = Green, fontWeight = FontWeight.Bold)
        val sections = listOf(
            "القرآن الكريم" to 1,
            "مواقيت الصلاة والأذان" to 2,
            "الأذكار والسبحة" to 3,
            "القبلة" to 4,
            "التنبيهات" to 4,
            "أسماء الله الحسنى" to 4,
            "التقويم الهجري" to 4
        )
        LazyColumn(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            items(sections) { (title, target) ->
                Card(
                    onClick = { onSelect(target) },
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Row(
                        Modifier.fillMaxWidth().padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.AutoAwesome, null, tint = Gold)
                        Spacer(Modifier.width(12.dp))
                        Text(title, modifier = Modifier.weight(1f), color = Ink, fontWeight = FontWeight.Medium)
                        Icon(Icons.Default.ChevronLeft, null, tint = Green)
                    }
                }
            }
        }
    }
}

@Composable
private fun Page(title: String, body: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(title, style = MaterialTheme.typography.headlineSmall, color = Green, fontWeight = FontWeight.Bold)
        body()
    }
}

@Composable
private fun QuranScreen() {
    val surahs = listOf("الفاتحة", "البقرة", "آل عمران", "النساء", "المائدة", "الأنعام", "الأعراف", "الأنفال", "التوبة", "يونس")
    Page("القرآن الكريم") {
        Text("سيتم تحميل فهرس المصحف والنص العثماني من مصدر موثوق بعد تثبيت مصدر البيانات والترخيص.")
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(surahs) { surah ->
                ListItem(
                    headlineContent = { Text(surah, color = Ink) },
                    leadingContent = { Icon(Icons.Default.MenuBook, null, tint = Gold) },
                    colors = ListItemDefaults.colors(containerColor = Color.White)
                )
            }
        }
    }
}

@Composable
private fun PrayerScreen() {
    Page("مواقيت الصلاة") {
        Card(colors = CardDefaults.cardColors(containerColor = Color.White)) {
            Column(Modifier.fillMaxWidth().padding(18.dp)) {
                Text("مصر — طريقة الحساب المصرية", color = Green, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(6.dp))
                Text("سيتم تحديد الموقع وحساب المواقيت محليًا بعد منح إذن الموقع.")
            }
        }
        listOf("الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء").forEach { name ->
            ListItem(
                headlineContent = { Text(name) },
                supportingContent = { Text("بانتظار تفعيل حساب المواقيت") },
                leadingContent = { Icon(Icons.Default.Schedule, null, tint = Gold) },
                colors = ListItemDefaults.colors(containerColor = Color.White)
            )
        }
    }
}

@Composable
private fun AzkarScreen() {
    var count by remember { mutableIntStateOf(0) }
    Page("الأذكار والسبحة") {
        Text("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center, style = MaterialTheme.typography.headlineSmall)
        Text(count.toString(), modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center, style = MaterialTheme.typography.displayLarge, color = Green)
        Button(
            onClick = { count++ },
            modifier = Modifier.fillMaxWidth().height(56.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Gold)
        ) { Text("تسبيح", color = Color.White) }
        OutlinedButton(onClick = { count = 0 }, modifier = Modifier.fillMaxWidth()) { Text("إعادة العداد", color = Green) }
        Text("سيتم إضافة أبواب أذكار الصباح والمساء والنوم والصلاة بمصادر موثقة.")
    }
}

@Composable
private fun MoreScreen() {
    Page("المزيد") {
        listOf("اتجاه القبلة", "التنبيهات والأذان", "أسماء الله الحسنى", "التقويم الهجري").forEach { title ->
            ListItem(
                headlineContent = { Text(title) },
                leadingContent = { Icon(Icons.Default.AutoAwesome, null, tint = Gold) },
                colors = ListItemDefaults.colors(containerColor = Color.White)
            )
        }
    }
}
