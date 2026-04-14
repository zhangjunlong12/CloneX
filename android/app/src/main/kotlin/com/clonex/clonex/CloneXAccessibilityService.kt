package com.clonex.clonex

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class CloneXAccessibilityService : AccessibilityService() {

    companion object {
        const val CHANNEL = "com.clonex/automation"
        var instance: CloneXAccessibilityService? = null
    }

    private lateinit var methodChannel: MethodChannel
    private var isRecording = false

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()

        val flutterEngine = (applicationContext as? io.flutter.embedding.engine.FlutterEngineCacheHolder)
            ?.getFlutterEngine(applicationContext as android.content.Context)

        methodChannel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL)
        setupMethodCallHandler()
    }

    private fun setupMethodCallHandler() {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "tap" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    performTap(x.toInt(), y.toInt())
                    result.success(true)
                }
                "longPress" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    val duration = call.argument<Int>("duration") ?: 500
                    performLongPress(x.toInt(), y.toInt(), duration)
                    result.success(true)
                }
                "swipe" -> {
                    val startX = call.argument<Double>("startX") ?: 0.0
                    val startY = call.argument<Double>("startY") ?: 0.0
                    val endX = call.argument<Double>("endX") ?: 0.0
                    val endY = call.argument<Double>("endY") ?: 0.0
                    performSwipe(startX.toInt(), startY.toInt(), endX.toInt(), endY.toInt())
                    result.success(true)
                }
                "input" -> {
                    val text = call.argument<String>("text") ?: ""
                    // 输入需要获取焦点后模拟
                    result.success(true)
                }
                "back" -> {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    result.success(true)
                }
                "home" -> {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    result.success(true)
                }
                "scroll" -> {
                    val x = call.argument<Double>("x") ?: 0.0
                    val y = call.argument<Double>("y") ?: 0.0
                    // 向上滚动
                    performSwipe(x.toInt(), y.toInt(), x.toInt(), (y + 300).toInt())
                    result.success(true)
                }
                "startRecording" -> {
                    isRecording = true
                    result.success(true)
                }
                "stopRecording" -> {
                    isRecording = false
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun performTap(x: Int, y: Int) {
        val path = Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()

        dispatchGesture(gesture, null, null)
    }

    private fun performLongPress(x: Int, y: Int, duration: Int) {
        val path = Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, duration.toLong()))
            .build()

        dispatchGesture(gesture, null, null)
    }

    private fun performSwipe(startX: Int, startY: Int, endX: Int, endY: Int) {
        val path = Path().apply {
            moveTo(startX.toFloat(), startY.toFloat())
            lineTo(endX.toFloat(), endY.toFloat())
        }

        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 300))
            .build()

        dispatchGesture(gesture, null, null)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isRecording) return

        // 记录用户操作事件
        when (event?.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                // 点击事件
            }
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                // 滚动事件
            }
            AccessibilityEvent.TYPE_VIEW_LONG_CLICKED -> {
                // 长按事件
            }
        }
    }

    override fun onInterrupt() {
        // 服务中断
    }
}
