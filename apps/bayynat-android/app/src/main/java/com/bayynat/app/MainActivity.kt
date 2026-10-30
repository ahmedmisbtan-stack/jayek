package com.bayynat.app

import android.os.Bundle
import android.content.Intent
import android.net.Uri
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.foundation.Image
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.bayynat.app.quran.QuranScreenContent
import com.bayynat.app.prayer.PrayerScreenContent
import com.bayynat.app.qibla.QiblaScreenContent
import com.bayynat.app.audio.AudioPlayerScreenContent
import com.bayynat.app.notifications.PrayerAlertsScreenContent
import com.bayynat.app.names.NamesScreenContent
import com.bayynat.app.azkar.AzkarScreenContent
import com.bayynat.app.content.HaqibatScreenContent
import com.bayynat.app.core.HijriDateProvider
import java.util.Date

private val Gold = Color(0xFFD99A32)
private val Green = Color(0xFF176B55)
private val Navy = Color(0xFF08264C)
private val Ivory = Color(0xFFFFF5E5)
private val Ink = Color(0xFF49351F)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContent { BayynatTheme { BayynatApp() } }
    }
}

@Composable
private fun BayynatTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Green,
            secondary = Gold,
            tertiary = Navy,
            background = Ivory,
            surface = Color.White,
            onBackground = Ink,
            onSurface = Ink
        ),
        content = content
    )
}

private data class Destination(val title: String, val icon: ImageVector)

private fun sectionIcon(target: Int): ImageVector = when (target) {
    1 -> Icons.Default.MenuBook
    2 -> Icons.Default.AccessTime
    3 -> Icons.Default.Favorite
    5 -> Icons.Default.Explore
    6 -> Icons.Default.Notifications
    7 -> Icons.Default.Star
    8 -> Icons.Default.CalendarToday
    9 -> Icons.Default.Gavel
    10 -> Icons.Default.LibraryBooks
    11 -> Icons.Default.History
    12 -> Icons.Default.Work
    13 -> Icons.Default.VolumeUp
    14 -> Icons.Default.Article
    15 -> Icons.Default.Edit
    16 -> Icons.Default.Mic
    17 -> Icons.Default.Forum
    else -> Icons.Default.AutoAwesome
}

@OptIn(ExperimentalMaterial3Api::class)
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
    val hijriToday = remember { HijriDateProvider.today() }
    BackHandler(enabled = selected >= 5) { selected = 4 }

    Scaffold(
        containerColor = Ivory,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Image(
                            painter = painterResource(R.drawable.bayynat_logo),
                            contentDescription = "شعار بيّنات",
                            modifier = Modifier.size(38.dp)
                        )
                        Column {
                            Text("بيّنات", color = Navy, fontWeight = FontWeight.Bold)
                            Text(hijriToday.full, color = Ink, style = MaterialTheme.typography.labelSmall)
                        }
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Ivory)
            )
        },
        bottomBar = {
            NavigationBar(containerColor = Color.White, contentColor = Green) {
                destinations.forEachIndexed { index, item ->
                    NavigationBarItem(
                        selected = if (selected >= 5) index == 4 else selected == index,
                        onClick = { selected = index },
                        icon = { Icon(item.icon, contentDescription = item.title) },
                        label = { Text(item.title) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Green,
                            selectedTextColor = Green,
                            indicatorColor = Gold.copy(alpha = .22f)
                        )
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
                4 -> MoreScreen(onSelect = { selected = it })
                5 -> QiblaScreenContent()
                6 -> PrayerAlertsScreenContent(onOpenPrayerTimes = { selected = 2 })
                7 -> NamesScreenContent()
                8 -> HijriCalendarScreen()
                9 -> OfficialContentScreen("الفقه", "https://www.bayynat.org.lb/article/category/25910/%D9%81%D9%82%D9%87/ar", "الرسائل العملية، فقه الشريعة، كيفية تأدية العبادات، مصطلحات فقهية، مناسك الحج")
                10 -> OfficialContentScreen("المكتبة", "https://www.bayynat.org.lb/library/category/25922/%D8%A7%D9%84%D9%85%D9%83%D8%AA%D8%A8%D8%A9/ar", "قرآنيات، كتب عن السيد، الأسرة والمجتمع، أهل البيت، الأخلاق، الحديث، الدعاء، الفكر الإسلامي")
                11 -> OfficialContentScreen("أرشيف السيد", "https://www.bayynat.org.lb/article/category/440/%D8%A3%D8%B1%D8%B4%D9%8A%D9%81-%D8%A7%D9%84%D8%B3%D9%8A%D8%AF/ar", "الخطب والبيانات والأخبار والسيرة والمقابلات والحوارات والأناشيد")
                13 -> AudioPlayerScreenContent()
                14 -> OfficialContentScreen("أخبار بيّنات", "https://www.bayynat.org.lb/article/category/31987/%D8%A3%D8%AE%D8%A8%D8%A7%D8%B1-%D8%A8%D9%8A%D9%86%D8%A7%D8%AA/ar", "أخبار الموقع والإعلانات والمواد الحديثة")
                15 -> OfficialContentScreen("كتابات", "https://www.bayynat.org.lb/article/category/31984/%D9%83%D8%AA%D8%A7%D8%A8%D8%A7%D8%AA/ar", "كتابات فكرية وثقافية واجتماعية")
                16 -> OfficialContentScreen("محاضرات", "https://www.bayynat.org.lb/article/category/31983/%D9%85%D8%AD%D8%A7%D8%B6%D8%B1%D8%A7%D8%AA/ar", "محاضرات ودروس مرئية ومسموعة")
                17 -> OfficialContentScreen("مقابلات", "https://www.bayynat.org.lb/article/category/1050/%D9%85%D9%82%D8%A7%D8%A8%D9%84%D8%A7%D8%AA/ar", "مقابلات وحوارات فكرية وتربوية")
                12 -> HaqibatScreenContent()
                else -> MoreScreen(onSelect = { selected = it })
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
            colors = CardDefaults.cardColors(containerColor = Navy)
        ) {
            Box(Modifier.fillMaxWidth().background(Brush.linearGradient(listOf(Green, Navy)))) {
                Column(Modifier.fillMaxWidth().padding(22.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Image(painterResource(R.drawable.bayynat_mark), "شعار بيّنات", Modifier.size(66.dp))
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text("بيّنات", color = Gold, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                            Text("رفيق يومك إلى الطمأنينة", color = Color.White.copy(alpha = .92f))
                        }
                    }
                    Spacer(Modifier.height(20.dp))
                    Text("السلام عليكم", color = Color.White, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(6.dp))
                    Text("اجعل القرآن والذكر رفيق يومك", color = Color.White.copy(alpha = .9f))
                    Spacer(Modifier.height(18.dp))
                    Text("مواقيت الصلاة", color = Gold, fontWeight = FontWeight.SemiBold)
                    Text("حدّد موقعك لعرض المواقيت، أو افتح خدمة بيّنات الرسمية", color = Color.White, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
        Text("أقسام بيّنات", style = MaterialTheme.typography.titleLarge, color = Navy, fontWeight = FontWeight.Bold)
        val sections = listOf(
            "القرآن الكريم" to 1,
            "مواقيت الصلاة والأذان" to 2,
            "الأذكار والسبحة" to 3,
            "القبلة" to 5,
            "التنبيهات" to 6,
            "أسماء الله الحسنى" to 7,
            "التقويم الهجري" to 8,
            "الفقه" to 9,
            "المكتبة" to 10,
            "أرشيف السيد" to 11,
            "حقيبة بيّنات" to 12
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
                        Icon(sectionIcon(target), null, tint = Gold)
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
        Text(title, style = MaterialTheme.typography.headlineSmall, color = Navy, fontWeight = FontWeight.Bold)
        body()
    }
}

@Composable
private fun QuranScreen() {
    QuranScreenContent()
}

@Composable
private fun PrayerScreen() {
    PrayerScreenContent()
}

@Composable
private fun AzkarScreen() {
    AzkarScreenContent()
}

@Composable
private fun MoreScreen(onSelect: (Int) -> Unit) {
    val entries = listOf(
        "اتجاه القبلة" to 5,
        "التنبيهات والأذان" to 6,
        "أسماء الله الحسنى" to 7,
        "التقويم الهجري" to 8,
        "الفقه" to 9,
        "المكتبة" to 10,
        "أرشيف السيد" to 11,
        "حقيبة بيّنات" to 12,
        "الصوتيات والتلاوات" to 13,
        "أخبار بيّنات" to 14,
        "كتابات" to 15,
        "محاضرات" to 16,
        "مقابلات" to 17
    )
    Column(Modifier.fillMaxSize().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("المزيد", style = MaterialTheme.typography.headlineSmall, color = Navy, fontWeight = FontWeight.Bold)
        LazyColumn(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            items(entries) { (title, target) ->
                Card(
                    onClick = { onSelect(target) },
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(sectionIcon(target), null, tint = Gold)
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
private fun SimpleSectionScreen(title: String, description: String) {
    Page(title) {
        Card(colors = CardDefaults.cardColors(containerColor = Color.White)) {
            Text(description, modifier = Modifier.padding(18.dp))
        }
    }
}

@Composable
private fun HijriCalendarScreen() {
    val context = androidx.compose.ui.platform.LocalContext.current
    val prefs = remember(context) { context.getSharedPreferences("bayynat_hijri", 0) }
    var offset by remember { mutableIntStateOf(prefs.getInt("day_offset", 0).coerceIn(-2, 2)) }
    val hijri = remember(offset) {
        HijriDateProvider.today(Date(System.currentTimeMillis() + offset * 86_400_000L))
    }
    Page("التقويم الهجري") {
        Card(colors = CardDefaults.cardColors(containerColor = Navy), shape = RoundedCornerShape(22.dp)) {
            Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(hijri.day, color = Gold, style = MaterialTheme.typography.displayMedium, fontWeight = FontWeight.Bold)
                Text(hijri.month, color = Color.White, style = MaterialTheme.typography.headlineSmall)
                Text(hijri.year + " هـ", color = Color.White)
            }
        }
        Text("فرق ضبط التاريخ: $offset يوم")
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = {
                offset = (offset - 1).coerceAtLeast(-2)
                prefs.edit().putInt("day_offset", offset).apply()
            }) { Text("اليوم السابق") }
            OutlinedButton(onClick = {
                offset = (offset + 1).coerceAtMost(2)
                prefs.edit().putInt("day_offset", offset).apply()
            }) { Text("اليوم التالي") }
        }
        Text("يمكن ضبط التاريخ يدويًا لمطابقة إعلان بداية الشهر في بلدك أو لدى المرجع؛ فالتقويم الحسابي قد يختلف عن الرؤية الشرعية.")
    }
}

@Composable
private fun OfficialContentScreen(title: String, url: String, contents: String) {
    val context = androidx.compose.ui.platform.LocalContext.current
    Page(title) {
        Card(colors = CardDefaults.cardColors(containerColor = Color.White), shape = RoundedCornerShape(18.dp)) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(contents, color = Ink)
                Button(
                    onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("فتح القسم الأصلي في موقع بيّنات") }
                Text("تُفتح المادة الأصلية في المتصفح لضمان عرض النصوص والوثائق والوسائط من مصدرها الرسمي دون نسخ غير مصرح به.")
            }
        }
    }
}
