package com.bayynat.app.core

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.tan

object QiblaCalculator {
    private const val KAABA_LATITUDE = 21.4225
    private const val KAABA_LONGITUDE = 39.8262

    /** True-north bearing in degrees clockwise from north, in [0, 360). */
    fun bearing(latitude: Double, longitude: Double): Double {
        require(latitude in -90.0..90.0)
        require(longitude in -180.0..180.0)
        val userLat = Math.toRadians(latitude)
        val kaabaLat = Math.toRadians(KAABA_LATITUDE)
        val deltaLongitude = Math.toRadians(KAABA_LONGITUDE - longitude)
        val y = sin(deltaLongitude)
        val x = cos(userLat) * tan(kaabaLat) - sin(userLat) * cos(deltaLongitude)
        return (Math.toDegrees(atan2(y, x)) + 360.0) % 360.0
    }
}
