package com.bayynat.app.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class QiblaCalculatorTest {
    @Test fun bearingAtKaabaIsStable() {
        assertEquals(0.0, QiblaCalculator.bearing(21.4225, 39.8262), 0.001)
    }

    @Test fun bearingFromGreenwichIsInExpectedQuadrant() {
        val bearing = QiblaCalculator.bearing(0.0, 0.0)
        assertTrue(bearing in 58.0..59.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidLatitude() {
        QiblaCalculator.bearing(91.0, 0.0)
    }
}
