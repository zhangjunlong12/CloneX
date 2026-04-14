package com.clonex.clonex

import android.os.Build
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.DataOutputStream

class ShizukuPlugin(private val scope: CoroutineScope) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.clonex/shizuku"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                // Shizuku library not available, return false
                result.success(false)
            }
            "requestPermission" -> {
                result.error("UNAVAILABLE", "Shizuku not available", null)
            }
            "injectTap" -> {
                val x = call.argument<Double>("x")?.toFloat() ?: 0f
                val y = call.argument<Double>("y")?.toFloat() ?: 0f
                scope.launch {
                    val success = shellInputTap(x.toInt(), y.toInt())
                    result.success(success)
                }
            }
            "injectSwipe" -> {
                val x1 = call.argument<Double>("startX")?.toFloat() ?: 0f
                val y1 = call.argument<Double>("startY")?.toFloat() ?: 0f
                val x2 = call.argument<Double>("endX")?.toFloat() ?: 0f
                val y2 = call.argument<Double>("endY")?.toFloat() ?: 0f
                val duration = call.argument<Int>("duration")?.toLong() ?: 300L
                scope.launch {
                    val success = shellInputSwipe(x1.toInt(), y1.toInt(), x2.toInt(), y2.toInt(), duration.toInt())
                    result.success(success)
                }
            }
            "injectLongPress" -> {
                val x = call.argument<Double>("x")?.toFloat() ?: 0f
                val y = call.argument<Double>("y")?.toFloat() ?: 0f
                val duration = call.argument<Int>("duration")?.toLong() ?: 500L
                scope.launch {
                    val success = shellInputSwipe(x.toInt(), y.toInt(), x.toInt(), y.toInt(), duration.toInt())
                    result.success(success)
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun shellInputTap(x: Int, y: Int): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec("su")
                val os = DataOutputStream(process.outputStream)
                os.writeBytes("input tap $x $y\n")
                os.writeBytes("exit\n")
                os.flush()
                process.waitFor()
                val exitCode = process.exitValue()
                debugPrint("shellInputTap result: $exitCode")
                exitCode == 0
            } catch (e: Exception) {
                debugPrint("shellInputTap error: ${e.message}")
                // Fallback: try without su
                try {
                    val process = Runtime.getRuntime().exec("input tap $x $y")
                    process.waitFor()
                    true
                } catch (e2: Exception) {
                    debugPrint("shellInputTap fallback error: ${e2.message}")
                    false
                }
            }
        }
    }

    private suspend fun shellInputSwipe(x1: Int, y1: Int, x2: Int, y2: Int, duration: Int): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec("su")
                val os = DataOutputStream(process.outputStream)
                os.writeBytes("input swipe $x1 $y1 $x2 $y2 $duration\n")
                os.writeBytes("exit\n")
                os.flush()
                process.waitFor()
                val exitCode = process.exitValue()
                debugPrint("shellInputSwipe result: $exitCode")
                exitCode == 0
            } catch (e: Exception) {
                debugPrint("shellInputSwipe error: ${e.message}")
                // Fallback: try without su
                try {
                    val process = Runtime.getRuntime().exec("input swipe $x1 $y1 $x2 $y2 $duration")
                    process.waitFor()
                    true
                } catch (e2: Exception) {
                    debugPrint("shellInputSwipe fallback error: ${e2.message}")
                    false
                }
            }
        }
    }

    private fun debugPrint(msg: String) {
        android.util.Log.d("ShizukuPlugin", msg)
    }
}
