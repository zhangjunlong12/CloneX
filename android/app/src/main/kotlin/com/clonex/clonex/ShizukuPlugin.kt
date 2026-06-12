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
                scope.launch {
                    result.success(hasRootShell())
                }
            }
            "requestPermission" -> {
                result.error("UNAVAILABLE", "Shizuku SDK is not integrated yet", null)
            }
            "injectTap" -> {
                val x = call.argument<Number>("x")?.toFloat() ?: 0f
                val y = call.argument<Number>("y")?.toFloat() ?: 0f
                scope.launch {
                    val success = shellInputTap(x.toInt(), y.toInt())
                    result.success(success)
                }
            }
            "injectSwipe" -> {
                val x1 = call.argument<Number>("startX")?.toFloat() ?: 0f
                val y1 = call.argument<Number>("startY")?.toFloat() ?: 0f
                val x2 = call.argument<Number>("endX")?.toFloat() ?: 0f
                val y2 = call.argument<Number>("endY")?.toFloat() ?: 0f
                val duration = call.argument<Int>("duration")?.toLong() ?: 300L
                scope.launch {
                    val success = shellInputSwipe(x1.toInt(), y1.toInt(), x2.toInt(), y2.toInt(), duration.toInt())
                    result.success(success)
                }
            }
            "injectLongPress" -> {
                val x = call.argument<Number>("x")?.toFloat() ?: 0f
                val y = call.argument<Number>("y")?.toFloat() ?: 0f
                val duration = call.argument<Int>("duration")?.toLong() ?: 500L
                scope.launch {
                    val success = shellInputSwipe(x.toInt(), y.toInt(), x.toInt(), y.toInt(), duration.toInt())
                    result.success(success)
                }
            }
            "injectText" -> {
                val text = call.argument<String>("text") ?: ""
                scope.launch {
                    result.success(shellInputText(text))
                }
            }
            "injectKeyEvent" -> {
                val keyCode = call.argument<Int>("keyCode") ?: 0
                scope.launch {
                    result.success(shellInputKeyEvent(keyCode))
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun hasRootShell(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "true"))
                process.waitFor()
                process.exitValue() == 0
            } catch (e: Exception) {
                false
            }
        }
    }

    private suspend fun shellInputTap(x: Int, y: Int): Boolean {
        return runInputCommand("input tap $x $y")
    }

    private suspend fun shellInputSwipe(x1: Int, y1: Int, x2: Int, y2: Int, duration: Int): Boolean {
        return runInputCommand("input swipe $x1 $y1 $x2 $y2 $duration")
    }

    private suspend fun shellInputText(text: String): Boolean {
        val shellText = text
            .replace(" ", "%s")
            .filter { it.isLetterOrDigit() || it in setOf('%', '.', '_', '-') }
        if (shellText.isEmpty()) return false
        return runInputCommand("input text $shellText")
    }

    private suspend fun shellInputKeyEvent(keyCode: Int): Boolean {
        if (keyCode <= 0) return false
        return runInputCommand("input keyevent $keyCode")
    }

    private suspend fun runInputCommand(command: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val process = Runtime.getRuntime().exec("su")
                val os = DataOutputStream(process.outputStream)
                os.writeBytes("$command\n")
                os.writeBytes("exit\n")
                os.flush()
                process.waitFor()
                val exitCode = process.exitValue()
                debugPrint("runInputCommand(su) result: $exitCode")
                if (exitCode == 0) {
                    true
                } else {
                    runInputCommandWithoutSu(command)
                }
            } catch (e: Exception) {
                debugPrint("runInputCommand(su) error: ${e.message}")
                runInputCommandWithoutSu(command)
            }
        }
    }

    private fun runInputCommandWithoutSu(command: String): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(command)
            process.waitFor()
            val exitCode = process.exitValue()
            debugPrint("runInputCommand(no su) result: $exitCode")
            exitCode == 0
        } catch (e: Exception) {
            debugPrint("runInputCommand(no su) error: ${e.message}")
            false
        }
    }

    private fun debugPrint(msg: String) {
        android.util.Log.d("ShizukuPlugin", msg)
    }
}
