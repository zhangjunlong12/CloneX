package com.clonex.clonex

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.clonex/automation"
        const val RECORDING_CHANNEL = "com.clonex/recording"
        const val SHIZUKU_CHANNEL = "com.clonex/shizuku"
        const val ELEMENT_CHANNEL = "com.clonex/element"
        const val ELEMENT_RECORDING_CHANNEL = "com.clonex/element_recording"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var recordingChannel: MethodChannel
    private lateinit var shizukuChannel: MethodChannel
    private lateinit var elementChannel: MethodChannel
    private lateinit var elementRecordingChannel: EventChannel
    private lateinit var shizukuPlugin: ShizukuPlugin
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 初始化 Shizuku 插件（Shell fallback）
        shizukuPlugin = ShizukuPlugin(scope)

        // 自动化控制通道
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            val service = CloneXAccessibilityService.instance

            when (call.method) {
                "tap" -> {
                    val x = call.argument<Double>("x")?.toInt() ?: 0
                    val y = call.argument<Double>("y")?.toInt() ?: 0
                    service?.performTap(x, y)
                    result.success(true)
                }
                "longPress" -> {
                    val x = call.argument<Double>("x")?.toInt() ?: 0
                    val y = call.argument<Double>("y")?.toInt() ?: 0
                    val duration = call.argument<Int>("duration") ?: 500
                    service?.performLongPress(x, y, duration)
                    result.success(true)
                }
                "swipe" -> {
                    val startX = call.argument<Double>("startX")?.toInt() ?: 0
                    val startY = call.argument<Double>("startY")?.toInt() ?: 0
                    val endX = call.argument<Double>("endX")?.toInt() ?: 0
                    val endY = call.argument<Double>("endY")?.toInt() ?: 0
                    service?.performSwipe(startX, startY, endX, endY)
                    result.success(true)
                }
                "back" -> {
                    service?.performBack()
                    result.success(true)
                }
                "home" -> {
                    service?.performHome()
                    result.success(true)
                }
                "scroll" -> {
                    val x = call.argument<Double>("x")?.toInt() ?: 0
                    val y = call.argument<Double>("y")?.toInt() ?: 0
                    service?.performSwipe(x, y, x, y + 300)
                    result.success(true)
                }
                "input" -> {
                    result.success(true)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(service != null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 录制通道 - 同时控制两个服务
        recordingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL)
        recordingChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    CloneXAccessibilityService.isRecording = true
                    AccessibilityElementService.isRecording = true
                    result.success(true)
                }
                "stopRecording" -> {
                    CloneXAccessibilityService.isRecording = false
                    AccessibilityElementService.isRecording = false
                    result.success(true)
                }
                "isRecording" -> {
                    result.success(CloneXAccessibilityService.isRecording)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Shell 注入通道 (Shizuku fallback)
        shizukuChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHIZUKU_CHANNEL)
        shizukuChannel.setMethodCallHandler(shizukuPlugin)

        // 元素级无障碍通道
        elementChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ELEMENT_CHANNEL)
        elementChannel.setMethodCallHandler { call, result ->
            val service = AccessibilityElementService.instance

            when (call.method) {
                "findAndClickByText" -> {
                    val text = call.argument<String>("text") ?: ""
                    result.success(service?.findAndClickByText(text) ?: false)
                }
                "findAndClickByViewId" -> {
                    val viewId = call.argument<String>("viewId") ?: ""
                    result.success(service?.findAndClickByViewId(viewId) ?: false)
                }
                "findAndClickByDescription" -> {
                    val description = call.argument<String>("description") ?: ""
                    result.success(service?.findAndClickByDescription(description) ?: false)
                }
                "findAndScroll" -> {
                    result.success(service?.findAndScroll() ?: false)
                }
                "isElementServiceEnabled" -> {
                    result.success(service != null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 元素录制事件通道
        elementRecordingChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, ELEMENT_RECORDING_CHANNEL)
        elementRecordingChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                AccessibilityElementService.instance?.setEventSink(events)
            }

            override fun onCancel(arguments: Any?) {
                AccessibilityElementService.instance?.setEventSink(null)
            }
        })
    }
}