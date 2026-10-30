package com.bayynat.app.audio

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

@Composable
fun AudioPlayerScreenContent() {
    val context = LocalContext.current
    val player = remember(context) { QuranAudioController(context) }
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
