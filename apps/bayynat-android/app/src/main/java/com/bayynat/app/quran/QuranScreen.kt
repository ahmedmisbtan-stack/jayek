package com.bayynat.app.quran

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun QuranScreenContent() {
    val context = LocalContext.current
    val repository = remember(context) { QuranRepository(context) }
    val preferences = remember(context) { context.getSharedPreferences("quran_cache_v1", 0) }
    var lastSurahNumber by remember { mutableIntStateOf(preferences.getInt("last_surah", 0)) }
    var query by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    var surahs by remember { mutableStateOf<List<SurahDto>>(emptyList()) }
    var selected by remember { mutableStateOf<SurahDetailDto?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    fun loadCatalogue() {
        scope.launch {
            loading = true
            error = null
            try {
                surahs = withContext(Dispatchers.IO) { repository.getSurahs() }
            } catch (_: Exception) {
                error = "تعذّر تحميل الفهرس. تحقق من الاتصال بالإنترنت ثم أعد المحاولة."
            } finally {
                loading = false
            }
        }
    }

    LaunchedEffect(Unit) { loadCatalogue() }

    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (selected == null) {
            Text("القرآن الكريم", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            OutlinedTextField(value = query, onValueChange = { query = it }, label = { Text("ابحث باسم السورة") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Text("فهرس السور — نص عثماني، مع حفظ السور التي تفتحها للقراءة دون اتصال")
            if (lastSurahNumber in 1..114 && !loading) {
                Button(
                    onClick = {
                        scope.launch {
                            loading = true
                            error = null
                            try {
                                selected = withContext(Dispatchers.IO) { repository.getSurah(lastSurahNumber) }
                            } catch (_: Exception) {
                                error = "تعذّر استعادة آخر موضع قراءة."
                            } finally {
                                loading = false
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Text("متابعة آخر قراءة — سورة رقم $lastSurahNumber") }
            }
            when {
                loading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally))
                error != null && surahs.isEmpty() -> {
                    Text(error!!, color = MaterialTheme.colorScheme.error)
                    Button(onClick = { loadCatalogue() }) { Text("إعادة المحاولة") }
                }
                else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(surahs.filter { it.name.contains(query, true) || it.englishName.contains(query, true) || it.number.toString() == query }, key = { it.number }) { surah ->
                        Card(
                            onClick = {
                                scope.launch {
                                    loading = true
                                    error = null
                                    try {
                                        selected = withContext(Dispatchers.IO) { repository.getSurah(surah.number) }
                                        lastSurahNumber = surah.number
                                        preferences.edit().putInt("last_surah", surah.number).putInt("last_ayah", 1).apply()
                                    } catch (_: Exception) {
                                        error = "تعذّر فتح السورة. تحقق من الاتصال وحاول مجددًا."
                                    } finally {
                                        loading = false
                                    }
                                }
                            },
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            shape = RoundedCornerShape(14.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(14.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(surah.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                                    Text("${surah.numberOfAyahs} آية • ${if (surah.revelationType == "Meccan") "مكية" else "مدنية"}",
                                        style = MaterialTheme.typography.bodySmall)
                                }
                                Text(surah.number.toString(), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }
            error?.let { if (surahs.isNotEmpty()) Text(it, color = MaterialTheme.colorScheme.error) }
        } else {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedButton(onClick = { selected = null }) { Text("فهرس السور") }
                Text(selected!!.name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            }
            LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(selected!!.ayahs, key = { it.number }) { ayah ->
                    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                        Text(
                            ayah.text,
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.Right,
                            style = MaterialTheme.typography.headlineSmall
                        )
                        Text("﴿${ayah.numberInSurah}﴾", color = MaterialTheme.colorScheme.secondary)
                        HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
                    }
                }
            }
        }
        Text(QuranAttribution.NOTICE, style = MaterialTheme.typography.labelSmall)
    }
}
