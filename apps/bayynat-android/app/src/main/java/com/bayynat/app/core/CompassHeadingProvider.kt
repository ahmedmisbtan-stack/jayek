package com.bayynat.app.core

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Device compass heading from the rotation-vector sensor.
 * Values are magnetic-north azimuths; callers should apply declination when
 * true-north alignment is required and clearly communicate calibration needs.
 */
class CompassHeadingProvider(context: Context) : SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationSensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val mutableHeading = MutableStateFlow<Double?>(null)
    val heading: StateFlow<Double?> = mutableHeading.asStateFlow()
    val isAvailable: Boolean get() = rotationSensor != null

    fun start() {
        rotationSensor?.let {
            manager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    fun stop() {
        manager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) return
        val rotation = FloatArray(9)
        val orientation = FloatArray(3)
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        SensorManager.getOrientation(rotation, orientation)
        mutableHeading.value = ((Math.toDegrees(orientation[0].toDouble()) + 360.0) % 360.0)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
