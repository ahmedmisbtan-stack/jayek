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
 * Device compass heading. Prefers the fused rotation-vector sensor and falls
 * back to accelerometer + magnetometer when that sensor is unavailable.
 */
class CompassHeadingProvider(context: Context) : SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationSensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val magnetometer = manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private val gravityValues = FloatArray(3)
    private val magneticValues = FloatArray(3)
    private var hasGravity = false
    private var hasMagnetic = false
    private val mutableHeading = MutableStateFlow<Double?>(null)
    val heading: StateFlow<Double?> = mutableHeading.asStateFlow()
    val isAvailable: Boolean get() = rotationSensor != null || (accelerometer != null && magnetometer != null)

    fun start() {
        if (rotationSensor != null) {
            manager.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_UI)
        } else {
            accelerometer?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
            magnetometer?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
        }
    }

    fun stop() {
        manager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                val rotation = FloatArray(9)
                val orientation = FloatArray(3)
                SensorManager.getRotationMatrixFromVector(rotation, event.values)
                SensorManager.getOrientation(rotation, orientation)
                publishHeading(orientation[0].toDouble())
            }
            Sensor.TYPE_ACCELEROMETER -> {
                event.values.copyInto(gravityValues)
                hasGravity = true
                updateFallbackHeading()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                event.values.copyInto(magneticValues)
                hasMagnetic = true
                updateFallbackHeading()
            }
        }
    }

    private fun updateFallbackHeading() {
        if (!hasGravity || !hasMagnetic || rotationSensor != null) return
        val rotation = FloatArray(9)
        val inclination = FloatArray(9)
        if (SensorManager.getRotationMatrix(rotation, inclination, gravityValues, magneticValues)) {
            val orientation = FloatArray(3)
            SensorManager.getOrientation(rotation, orientation)
            publishHeading(orientation[0].toDouble())
        }
    }

    private fun publishHeading(radians: Double) {
        mutableHeading.value = (Math.toDegrees(radians) + 360.0) % 360.0
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
