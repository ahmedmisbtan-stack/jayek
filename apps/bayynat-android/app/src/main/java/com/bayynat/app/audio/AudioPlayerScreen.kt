package com.bayynat.app.audio

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun AudioPlayerScreenContent() {
    val context = LocalContext.current
    val player = remember(context) { QuranAudioController(context) }
    val repository = remember { QuranAudioRepository() }
    val scope = rememberCoroutineScope()
    var surahNumber by remember { mutableStateOf("1") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    DisposableEffect(player) {
        onDispose { player.release() }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            runCatching {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            }
            player.play(uri, "تلاوة أو أذان")
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text("الصوتيات", style = MaterialTheme.typography.headlineSmall)
        Text("اختر ملف تلاوة أو أذان من جهازك. لا يضم التطبيق تسجيلات محمية بحقوق نشر دون إذن.")
        Text("التلاوة من مكتبة AlQuran Cloud — القارئ مشاري العفاسي")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = surahNumber,
                onValueChange = { surahNumber = it.filter(Char::isDigit).take(3) },
                label = { Text("رقم السورة (1–114)") },
                modifier = Modifier.weight(1f),
                singleLine = true
            )
            Button(
                enabled = !loading,
                onClick = {
                    val number = surahNumber.toIntOrNull()
                    if (number == null || number !in 1..114) {
                        error = "أدخل رقم سورة من 1 إلى 114."
                    } else {
                        scope.launch {
                            loading = true
                            error = null
                            try {
                                val audio = withContext(Dispatchers.IO) { repository.getSurahAudio(number) }
                                player.playPlaylist(audio.ayahs.map { it.audio }, audio.name)
                            } catch (_: Exception) {
                                error = "تعذّر تحميل التلاوة. تحقق من الاتصال وحاول مجددًا."
                            } finally {
                                loading = false
                            }
                        }
                    }
                }
            ) { Text("تشغيل") }
        }
        if (loading) CircularProgressIndicator()
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Button(
            onClick = { picker.launch(arrayOf("audio/*")) },
            modifier = Modifier.fillMaxWidth()
        ) { Text("اختيار ملف صوتي") }
        OutlinedButton(onClick = { player.pause() }, modifier = Modifier.fillMaxWidth()) { Text("إيقاف مؤقت") }
        OutlinedButton(onClick = { player.resume() }, modifier = Modifier.fillMaxWidth()) { Text("متابعة التشغيل") }
        OutlinedButton(onClick = { player.stop() }, modifier = Modifier.fillMaxWidth()) { Text("إيقاف") }
        Text("تظهر أدوات التحكم بالصوت على شاشة القفل عندما يسمح النظام والإعدادات بذلك.")
    }
}
