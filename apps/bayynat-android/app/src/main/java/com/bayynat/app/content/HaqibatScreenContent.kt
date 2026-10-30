package com.bayynat.app.content

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Icon

private data class HaqibatCategory(val title: String, val url: String)

@Composable
fun HaqibatScreenContent() {
    val context = LocalContext.current
    val categories = listOf(
        HaqibatCategory("أعمال ومستحبات", "https://www.bayynat.org.lb/article/category/11244/%D8%A3%D8%B9%D9%85%D8%A7%D9%84-%D9%88%D9%85%D8%B3%D8%AA%D8%AD%D8%A8%D8%A7%D8%AA/ar"),
        HaqibatCategory("مناسبات", "https://www.bayynat.org.lb/event/category/25761/%D9%85%D9%86%D8%A7%D8%B3%D8%A8%D8%A7%D8%AA/ar"),
        HaqibatCategory("مواقيت", "https://www.bayynat.org.lb/article/category/26552/%D9%85%D9%88%D8%A7%D9%82%D9%8A%D8%AA/ar"),
        HaqibatCategory("دعاء", "https://www.bayynat.org.lb/article/category/24735/%D8%AF%D8%B9%D8%A7%D8%A1/ar"),
        HaqibatCategory("أدعية الصحيفة السجادية", "https://www.bayynat.org.lb/book/%D9%85%D9%88%D9%82%D8%B9-%D8%A8%D9%8A%D9%86%D8%A7%D8%AA-articles/56050/%D8%A7%D9%84%D8%B5%D8%AD%D9%8A%D9%81%D8%A9-%D8%A7%D9%84%D8%B3%D8%AC%D8%A7%D8%AF%D9%8A%D8%A9/ar"),
        HaqibatCategory("أدعية مشهورة", "https://www.bayynat.org.lb/article/category/25954/%D8%A3%D8%AF%D8%B9%D9%8A%D8%A9-%D9%85%D8%B4%D9%87%D9%88%D8%B1%D8%A9/ar"),
        HaqibatCategory("شرح الدعاء", "https://www.bayynat.org.lb/article/category1/32061/%D8%B4%D8%B1%D8%AD-%D8%A7%D9%84%D8%AF%D8%B9%D8%A7%D8%A1/ar"),
        HaqibatCategory("المناجيات الخمس عشرة", "https://www.bayynat.org.lb/article/category/25952/%D8%A7%D9%84%D9%85%D9%86%D8%A7%D8%AC%D9%8A%D8%A7%D8%AA-%D8%A7%D9%84%D8%AE%D9%85%D8%B3-%D8%B9%D8%B4%D8%B1%D8%A9/ar"),
        HaqibatCategory("حول الدعاء", "https://www.bayynat.org.lb/article/category/31991/%D8%AD%D9%88%D9%84-%D8%A7%D9%84%D8%AF%D8%B9%D8%A7%D8%A1/ar"),
        HaqibatCategory("أدعية أيام الأسبوع", "https://www.bayynat.org.lb/article/category/6454/%D8%A3%D8%AF%D8%B9%D9%8A%D8%A9-%D8%A3%D9%8A%D8%A7%D9%85-%D8%A7%D9%84%D8%A3%D8%B3%D8%A8%D9%88%D8%B9/ar"),
        HaqibatCategory("كتب أدعية", "https://www.bayynat.org.lb/article/category/32099/%D9%83%D8%AA%D8%A8-%D8%A3%D8%AF%D8%B9%D9%8A%D8%A9/ar"),
        HaqibatCategory("زيارات", "https://www.bayynat.org.lb/article/category/25953/%D8%B2%D9%8A%D8%A7%D8%B1%D8%A7%D8%AA/ar"),
        HaqibatCategory("صفحات خاصة", "https://www.bayynat.org.lb/article/category/441/%D8%B5%D9%81%D8%AD%D8%A7%D8%AA-%D8%AE%D8%A7%D8%B5%D8%A9/ar"),
        HaqibatCategory("الحج", "https://www.bayynat.org.lb/article/category/22438/%D8%A7%D9%84%D8%AD%D8%AC/ar"),
        HaqibatCategory("رمضان", "https://www.bayynat.org.lb/article/category/21359/%D8%B1%D9%85%D8%B6%D8%A7%D9%86/ar")
    )

    Column(
        modifier = Modifier.fillMaxSize().padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text("حقيبة بيّنات", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("الأعمال والمستحبات والمناسبات والمواقيت والأدعية والزيارات كما رتّبها الموقع الرسمي.")
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(categories, key = { it.title }) { item ->
                Card(
                    onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(item.url))) },
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.AutoAwesome, contentDescription = null, tint = MaterialTheme.colorScheme.secondary)
                        Text(item.title, modifier = Modifier.weight(1f).padding(horizontal = 12.dp), fontWeight = FontWeight.Medium)
                        Icon(Icons.Default.ChevronLeft, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
    }
}
