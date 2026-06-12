package com.clonex.clonex

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 基于 UI 元素的自动化服务
 * 通过 AccessibilityService 查找并操作屏幕上的元素
 */
class AccessibilityElementService : AccessibilityService() {

    companion object {
        private const val TAG = "AccessibilityElement"
        var instance: AccessibilityElementService? = null
            private set
        var isRecording: Boolean = false
    }

    // 用于向 Flutter 发送录制事件的 EventChannel
    private var eventSink: EventChannel.EventSink? = null

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "AccessibilityElementService created")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isRecording = false
        eventSink = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "AccessibilityElementService connected")
    }

    /**
     * 开始录制
     */
    fun startRecording() {
        isRecording = true
        Log.d(TAG, "Recording started")
    }

    /**
     * 停止录制
     */
    fun stopRecording() {
        isRecording = false
        Log.d(TAG, "Recording stopped")
    }

    /**
     * 通过文本查找并点击元素
     */
    fun findAndClickByText(text: String): Boolean {
        Log.d(TAG, "findAndClickByText: searching for '$text'")
        val rootNode = rootInActiveWindow ?: run {
            Log.w(TAG, "findAndClickByText: rootInActiveWindow is null")
            return false
        }

        try {
            val nodes = rootNode.findAccessibilityNodeInfosByText(text)
            Log.d(TAG, "findAndClickByText: found ${nodes.size} nodes for '$text'")

            for (node in nodes) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                Log.d(TAG, "  Node: text=${node.text}, desc=${node.contentDescription}, bounds=$bounds, clickable=${node.isClickable}")

                if (node.isClickable) {
                    val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    Log.d(TAG, "  performAction(ACTION_CLICK) result: $result")
                    node.recycle()
                    return result
                }
            }

            // 如果没找到可点击的，尝试对第一个元素执行点击
            if (nodes.isNotEmpty()) {
                val firstNode = nodes[0]
                val bounds = Rect()
                firstNode.getBoundsInScreen(bounds)
                Log.d(TAG, "  No clickable node, clicking first match at bounds: $bounds")
                val clickResult = performClickAtBounds(bounds)
                Log.d(TAG, "  performClickAtBounds result: $clickResult")
                firstNode.recycle()
                return clickResult
            }
        } finally {
            rootNode.recycle()
        }
        return false
    }

    /**
     * 通过控件 ID 查找并点击
     */
    fun findAndClickByViewId(viewId: String): Boolean {
        Log.d(TAG, "findAndClickByViewId: searching for '$viewId'")
        val rootNode = rootInActiveWindow ?: run {
            Log.w(TAG, "findAndClickByViewId: rootInActiveWindow is null")
            return false
        }

        try {
            val nodes = rootNode.findAccessibilityNodeInfosByViewId(viewId)
            Log.d(TAG, "findAndClickByViewId: found ${nodes.size} nodes for '$viewId'")

            for (node in nodes) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                Log.d(TAG, "  Node: text=${node.text}, id=${node.viewIdResourceName}, bounds=$bounds, clickable=${node.isClickable}")

                if (node.isClickable) {
                    val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    Log.d(TAG, "  performAction(ACTION_CLICK) result: $result")
                    node.recycle()
                    return result
                }
            }

            // 尝试手势点击第一个
            if (nodes.isNotEmpty()) {
                val firstNode = nodes[0]
                val bounds = Rect()
                firstNode.getBoundsInScreen(bounds)
                Log.d(TAG, "  No clickable node, clicking at bounds: $bounds")
                val clickResult = performClickAtBounds(bounds)
                firstNode.recycle()
                return clickResult
            }
        } finally {
            rootNode.recycle()
        }
        return false
    }

    /**
     * 通过描述查找并点击
     */
    fun findAndClickByDescription(description: String): Boolean {
        Log.d(TAG, "findAndClickByDescription: searching for '$description'")
        val rootNode = rootInActiveWindow ?: run {
            Log.w(TAG, "findAndClickByDescription: rootInActiveWindow is null")
            return false
        }

        try {
            val nodes = mutableListOf<AccessibilityNodeInfo>()
            findNodesByDescription(rootNode, description, nodes)
            Log.d(TAG, "findAndClickByDescription: found ${nodes.size} nodes")

            for (node in nodes) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                Log.d(TAG, "  Node: desc=${node.contentDescription}, bounds=$bounds, clickable=${node.isClickable}")

                if (node.isClickable) {
                    val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    Log.d(TAG, "  performAction(ACTION_CLICK) result: $result")
                    node.recycle()
                    return result
                }
            }
        } finally {
            rootNode.recycle()
        }
        return false
    }

    /**
     * 设置当前聚焦输入框文本。用于重放录制到的输入操作。
     */
    fun setFocusedText(text: String): Boolean {
        val rootNode = rootInActiveWindow ?: run {
            Log.w(TAG, "setFocusedText: rootInActiveWindow is null")
            return false
        }

        try {
            val focusedNode = rootNode.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            val target = focusedNode ?: findEditableNode(rootNode)
            if (target == null) {
                Log.w(TAG, "setFocusedText: no editable node found")
                return false
            }

            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            val result = target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            Log.d(TAG, "setFocusedText result: $result")
            if (focusedNode != null) {
                focusedNode.recycle()
            } else {
                target.recycle()
            }
            return result
        } finally {
            rootNode.recycle()
        }
    }

    /**
     * 通过边界坐标执行点击
     */
    private fun performClickAtBounds(bounds: Rect): Boolean {
        val centerX = bounds.centerX()
        val centerY = bounds.centerY()
        Log.d(TAG, "performClickAtBounds: center=($centerX, $centerY)")

        val path = Path().apply {
            moveTo(centerX.toFloat(), centerY.toFloat())
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()

        val result = dispatchGesture(gesture, null, null)
        Log.d(TAG, "dispatchGesture at ($centerX, $centerY) result: $result")
        return result
    }

    /**
     * 查找并滑动列表
     */
    fun findAndScroll(direction: Int = AccessibilityNodeInfo.ACTION_SCROLL_FORWARD): Boolean {
        Log.d(TAG, "findAndScroll: direction=$direction")
        val rootNode = rootInActiveWindow ?: run {
            Log.w(TAG, "findAndScroll: rootInActiveWindow is null")
            return false
        }

        try {
            var result = rootNode.performAction(direction)
            if (result) {
                Log.d(TAG, "Scroll succeeded on root node")
                return true
            }

            val scrollableNodes = mutableListOf<AccessibilityNodeInfo>()
            findScrollableNodes(rootNode, scrollableNodes)
            Log.d(TAG, "Found ${scrollableNodes.size} scrollable nodes")

            for (node in scrollableNodes) {
                result = node.performAction(direction)
                if (result) {
                    Log.d(TAG, "Scroll succeeded on scrollable container")
                    return true
                }
            }
        } finally {
            rootNode.recycle()
        }
        return false
    }

    private fun findScrollableNodes(
        node: AccessibilityNodeInfo,
        result: MutableList<AccessibilityNodeInfo>
    ) {
        if (node.isScrollable) {
            result.add(node)
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findScrollableNodes(child, result)
                child.recycle()
            }
        }
    }

    private fun findNodesByDescription(
        node: AccessibilityNodeInfo,
        description: String,
        result: MutableList<AccessibilityNodeInfo>
    ) {
        val nodeDescription = node.contentDescription?.toString()
        if (nodeDescription != null && nodeDescription.contains(description, ignoreCase = true)) {
            result.add(AccessibilityNodeInfo.obtain(node))
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                findNodesByDescription(child, description, result)
                child.recycle()
            }
        }
    }

    private fun findEditableNode(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) {
            return AccessibilityNodeInfo.obtain(node)
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { child ->
                val editable = findEditableNode(child)
                child.recycle()
                if (editable != null) {
                    return editable
                }
            }
        }
        return null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isRecording) return

        when (event?.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                Log.d(TAG, "onAccessibilityEvent: TYPE_VIEW_CLICKED, isRecording=true")
                event.source?.let { source ->
                    recordClickAction(source)
                    source.recycle()
                }
            }
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                Log.d(TAG, "onAccessibilityEvent: TYPE_VIEW_SCROLLED, isRecording=true")
                event.source?.let { source ->
                    recordScrollAction(event, source)
                    source.recycle()
                }
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                Log.d(TAG, "onAccessibilityEvent: TYPE_VIEW_TEXT_CHANGED, isRecording=true")
                event.source?.let { source ->
                    recordTextAction(event, source)
                    source.recycle()
                }
            }
        }
    }

    private fun recordClickAction(source: AccessibilityNodeInfo) {
        val bounds = Rect()
        source.getBoundsInScreen(bounds)

        val elementText = source.text?.toString()
        val elementId = source.viewIdResourceName
        val elementDescription = source.contentDescription?.toString()

        Log.d(TAG, "Recorded click: text=$elementText, id=$elementId, desc=$elementDescription, bounds=$bounds")

        // 通过 EventChannel 发送给 Flutter
        eventSink?.success(mapOf(
            "type" to "click",
            "elementText" to elementText,
            "elementId" to elementId,
            "elementDescription" to elementDescription,
            "packageName" to source.packageName?.toString(),
            "className" to source.className?.toString(),
            "bounds" to mapOf("left" to bounds.left, "top" to bounds.top, "right" to bounds.right, "bottom" to bounds.bottom)
        ))
    }

    private fun recordScrollAction(event: AccessibilityEvent, source: AccessibilityNodeInfo) {
        val elementId = source.viewIdResourceName

        Log.d(TAG, "Recorded scroll: id=$elementId")

        eventSink?.success(mapOf(
            "type" to "scroll",
            "elementId" to elementId,
            "packageName" to event.packageName?.toString(),
            "className" to event.className?.toString()
        ))
    }

    private fun recordTextAction(event: AccessibilityEvent, source: AccessibilityNodeInfo) {
        val text = event.text.joinToString("")
        if (text.isEmpty()) return

        eventSink?.success(mapOf(
            "type" to "input",
            "text" to text,
            "elementText" to source.text?.toString(),
            "elementId" to source.viewIdResourceName,
            "elementDescription" to source.contentDescription?.toString(),
            "packageName" to event.packageName?.toString(),
            "className" to event.className?.toString()
        ))
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
    }
}
