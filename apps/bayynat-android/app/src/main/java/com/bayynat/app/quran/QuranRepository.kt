package com.bayynat.app.quran

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.Path

data class QuranApiResponse<T>(val code: Int, val status: String, val data: T)

data class SurahDto(
    val number: Int,
    val name: String,
    val englishName: String,
    val englishNameTranslation: String,
    val numberOfAyahs: Int,
    val revelationType: String
)

data class AyahDto(
    val number: Int,
    val text: String,
    val numberInSurah: Int,
    val juz: Int,
    val page: Int,
    val sajda: Any? = null
)

data class SurahDetailDto(
    val number: Int,
    val name: String,
    val englishName: String,
    val numberOfAyahs: Int,
    val ayahs: List<AyahDto>
)

private interface AlQuranCloudApi {
    @GET("surah")
    suspend fun getSurahs(): QuranApiResponse<List<SurahDto>>

    @GET("surah/{number}/quran-uthmani")
    suspend fun getSurah(@Path("number") number: Int): QuranApiResponse<SurahDetailDto>
}

/**
 * Fetches Uthmani Quran text and caches every successfully fetched surah.
 * The API is optional at runtime: previously opened surahs remain readable offline.
 */
class QuranRepository(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences("quran_cache_v1", Context.MODE_PRIVATE)
    private val gson = Gson()
    private val api = Retrofit.Builder()
        .baseUrl("https://api.alquran.cloud/v1/")
        .addConverterFactory(GsonConverterFactory.create(gson))
        .build()
        .create(AlQuranCloudApi::class.java)

    suspend fun getSurahs(): List<SurahDto> {
        return try {
            api.getSurahs().let { response ->
                require(response.code == 200 && response.status == "OK" && response.data.size == 114) {
                    "Quran catalogue response was incomplete or invalid"
                }
                response.data.also { result ->
                    preferences.edit().putString(SURAHS_KEY, gson.toJson(result)).apply()
                }
            }
        } catch (error: Exception) {
            readCachedSurahs() ?: throw error
        }
    }

    suspend fun getSurah(number: Int): SurahDetailDto {
        require(number in 1..114) { "Surah number must be between 1 and 114" }
        return try {
            api.getSurah(number).let { response ->
                require(
                    response.code == 200 &&
                        response.status == "OK" &&
                        response.data.number == number &&
                        response.data.ayahs.size == response.data.numberOfAyahs
                ) { "Surah response was incomplete or invalid" }
                response.data.also { result ->
                    preferences.edit().putString("$SURAH_PREFIX$number", gson.toJson(result)).apply()
                }
            }
        } catch (error: Exception) {
            readCachedSurah(number) ?: throw error
        }
    }

    private fun readCachedSurahs(): List<SurahDto>? {
        val raw = preferences.getString(SURAHS_KEY, null) ?: return null
        val type = object : TypeToken<List<SurahDto>>() {}.type
        return runCatching { gson.fromJson<List<SurahDto>>(raw, type) }.getOrNull()
    }

    private fun readCachedSurah(number: Int): SurahDetailDto? {
        val raw = preferences.getString("$SURAH_PREFIX$number", null) ?: return null
        return runCatching { gson.fromJson(raw, SurahDetailDto::class.java) }.getOrNull()
    }

    private companion object {
        const val SURAHS_KEY = "surah_catalogue"
        const val SURAH_PREFIX = "surah_"
    }
}
