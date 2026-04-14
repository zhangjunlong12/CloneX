package com.clonex.clonex

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class CloneXAccessibilityService : AccessibilityService() {

    companion object {
        var instance: CloneXAccessibilityService? = null
            private set
        var isRecording: Boolean = false
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d("CloneXAccessibility", "Service created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isRecording = false
        Log.d("CloneXAccessibility", "Service destroyed")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("CloneXAccessibility", "Service connected")
    }

    fun performTap(x: Int, y: Int): Boolean {
        Log.d("CloneXAccessibility", "performTap: x=$x, y=$y")
        val path = android.graphics.Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()

        return dispatchGesture(gesture, null, null)
    }

    fun performLongPress(x: Int, y: Int, duration: Int): Boolean {
        Log.d("CloneXAccessibility", "performLongPress: x=$x, y=$y, duration=$duration")
        val path = android.graphics.Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration.toLong()))
            .build()

        return dispatchGesture(gesture, null, null)
    }

    fun performSwipe(startX: Int, startY: Int, endX: Int, endY: Int): Boolean {
        Log.d("CloneXAccessibility", "performSwipe: ($startX,$startY) -> ($endX,$endY)")
        val path = android.graphics.Path().apply {
            moveTo(startX.toFloat(), startY.toFloat())
            lineTo(endX.toFloat(), endY.toFloat())
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()

        return dispatchGesture(gesture, null, null)
    }

    fun performBack() {
        Log.d("CloneXAccessibility", "performBack")
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    fun performHome() {
        Log.d("CloneXAccessibility", "performHome")
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        Log.d("CloneXAccessibility", "onAccessibilityEvent: ${event?.eventType}")
    }

    override fun onInterrupt() {
        Log.d("CloneXAccessibility", "Service interrupted")
    }
}
