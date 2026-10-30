package com.bayynat.app.audio

import com.google.gson.Gson
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.Path

data class AudioApiResponse<T>(val code: Int, val status: String, val data: T)
data class AyahAudioDto(val audio: String)
data class SurahAudioDto(val number: Int, val name: String, val ayahs: List<AyahAudioDto>)

private interface QuranAudioApi {
    @GET("surah/{number}/{edition}")
    suspend fun getSurahAudio(
        @Path("number") number: Int,
        @Path("edition") edition: String
    ): AudioApiResponse<SurahAudioDto>
}

class QuranAudioRepository {
    private val api = Retrofit.Builder()
        .baseUrl("https://api.alquran.cloud/v1/")
        .addConverterFactory(GsonConverterFactory.create(Gson()))
        .build()
        .create(QuranAudioApi::class.java)

    suspend fun getSurahAudio(number: Int, edition: String = "ar.alafasy"): SurahAudioDto {
        require(number in 1..114) { "Surah number must be between 1 and 114" }
        return api.getSurahAudio(number, edition).data.also { result ->
            require(result.ayahs.isNotEmpty() && result.ayahs.all { it.audio.isNotBlank() }) {
                "Audio edition did not return playable ayah URLs"
            }
        }
    }
}
