import Cocoa
import FlutterMacOS
import ApplicationServices

class AutomationPlugin: NSObject, FlutterPlugin {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRecording = false
    private var recordedEvents: [[String: Any]] = []
    private var recordingStartTime: Date?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.clonex/macos_automation", binaryMessenger: registrar.messenger())
        let instance = AutomationPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecording":
            startRecording(result: result)
        case "stopRecording":
            stopRecording(result: result)
        case "getRecordedEvents":
            result(recordedEvents)
        case "play":
            if let args = call.arguments as? [[String: Any]] {
                play(operations: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected array of operations", details: nil))
            }
        case "findElementAt":
            if let args = call.arguments as? [String: Any],
               let x = args["x"] as? Double,
               let y = args["y"] as? Double {
                findElementAt(x: x, y: y, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected x and y", details: nil))
            }
        case "isAccessibilityEnabled":
            result(checkAccessibilityEnabled())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Recording

    private func startRecording(result: @escaping FlutterResult) {
        guard !isRecording else {
            result(false)
            return
        }

        // 清理旧事件
        recordedEvents.removeAll()
        recordingStartTime = Date()

        // 创建事件 Tap
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                                      (1 << CGEventType.leftMouseUp.rawValue) |
                                      (1 << CGEventType.rightMouseDown.rawValue) |
                                      (1 << CGEventType.rightMouseUp.rawValue) |
                                      (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.scrollWheel.rawValue) |
                                      (1 << CGEventType.leftMouseDragged.rawValue) |
                                      (1 << CGEventType.rightMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let plugin = Unmanaged<AutomationPlugin>.fromOpaque(refcon).takeUnretainedValue()
            plugin.handleEvent(type: type, event: event)
            return Unmanaged.passRetained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            result(FlutterError(code: "TAP_FAILED", message: "Failed to create event tap. Check Accessibility permissions.", details: nil))
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isRecording = true
        result(true)
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard isRecording else {
            result(false)
            return
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isRecording = false

        result(true)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        guard isRecording else { return }

        var eventData: [String: Any] = [
            "timestamp": Date().timeIntervalSince(recordingStartTime ?? Date())
        ]

        switch type {
        case .leftMouseDown:
            eventData["type"] = "mouseDown"
            eventData["button"] = "left"
            let location = event.location
            eventData["x"] = location.x
            eventData["y"] = location.y
            eventData["elementInfo"] = getElementInfoAt(x: location.x, y: location.y)

        case .leftMouseUp:
            eventData["type"] = "mouseUp"
            eventData["button"] = "left"
            let location = event.location
            eventData["x"] = location.x
            eventData["y"] = location.y

        case .rightMouseDown:
            eventData["type"] = "mouseDown"
            eventData["button"] = "right"
            let location = event.location
            eventData["x"] = location.x
            eventData["y"] = location.y

        case .rightMouseUp:
            eventData["type"] = "mouseUp"
            eventData["button"] = "right"
            let location = event.location
            eventData["x"] = location.x
            eventData["y"] = location.y

        case .scrollWheel:
            eventData["type"] = "scroll"
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            eventData["deltaY"] = deltaY

        case .keyDown:
            eventData["type"] = "keyDown"
            eventData["keyCode"] = event.getIntegerValueField(.keyboardEventKeycode)
            if let unicodeString = event.copy() as? CGEvent,
               let chars = unicodeString.getCharacters(.zeroTerminatedUTF8) {
                eventData["characters"] = chars
            }

        case .keyUp:
            eventData["type"] = "keyUp"
            eventData["keyCode"] = event.getIntegerValueField(.keyboardEventKeycode)

        case .leftMouseDragged:
            eventData["type"] = "mouseDrag"
            eventData["button"] = "left"
            let location = event.location
            eventData["x"] = location.x
            eventData["y"] = location.y

        default:
            return
        }

        recordedEvents.append(eventData)
    }

    // MARK: - Element Finding

    private func findElementAt(x: Double, y: Double, result: @escaping FlutterResult) {
        let elementInfo = getElementInfoAt(x: x, y: y)
        result(elementInfo)
    }

    private func getElementInfoAt(x: CGFloat, y: CGFloat) -> [String: Any]? {
        var elementInfo: [String: Any] = [:]

        let systemWideElement = AXUIElementCreateSystemWide()

        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWideElement, x, y, &element)

        guard result == .success, let foundElement = element else {
            return nil
        }

        // 获取元素属性
        var title: CFTypeRef?
        if AXUIElementCopyAttributeValue(foundElement, kAXTitleAttribute as CFString, &title) == .success {
            if let title = title as? String {
                elementInfo["title"] = title
            }
        }

        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(foundElement, kAXRoleAttribute as CFString, &role) == .success {
            if let role = role as? String {
                elementInfo["role"] = role
            }
        }

        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(foundElement, kAXValueAttribute as CFString, &value) == .success {
            if let value = value as? String {
                elementInfo["value"] = value
            }
        }

        var description: CFTypeRef?
        if AXUIElementCopyAttributeValue(foundElement, kAXDescriptionAttribute as CFString, &description) == .success {
            if let description = description as? String {
                elementInfo["description"] = description
            }
        }

        var bounds: AXValue?
        if AXUIElementCopyAttributeValue(foundElement, kAXBoundsAttribute as CFString, &bounds) == .success {
            var rect = CGRect.zero
            if AXValueGetValue(bounds!, .cgRect, &rect) {
                elementInfo["bounds"] = [
                    "x": rect.origin.x,
                    "y": rect.origin.y,
                    "width": rect.size.width,
                    "height": rect.size.height
                ]
            }
        }

        foundElement.release()
        return elementInfo
    }

    // MARK: - Playback

    private func play(operations: [[String: Any]], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInteractive).async {
            for operation in operations {
                guard let type = operation["type"] as? String else { continue }

                switch type {
                case "click", "mouseDown":
                    if let x = operation["x"] as? Double,
                       let y = operation["y"] as? Double {
                        self.simulateClick(at: CGPoint(x: x, y: y), button: .left)
                        Thread.sleep(forTimeInterval: 0.05)
                    }

                case "rightClick":
                    if let x = operation["x"] as? Double,
                       let y = operation["y"] as? Double {
                        self.simulateClick(at: CGPoint(x: x, y: y), button: .right)
                        Thread.sleep(forTimeInterval: 0.05)
                    }

                case "scroll":
                    if let deltaY = operation["deltaY"] as? Double {
                        self.simulateScroll(deltaY: deltaY)
                        Thread.sleep(forTimeInterval: 0.1)
                    }

                case "keyDown", "keyUp":
                    if let keyCode = operation["keyCode"] as? Int64 {
                        self.simulateKey(keyCode: Int(keyCode), keyDown: type == "keyDown")
                        Thread.sleep(forTimeInterval: 0.02)
                    }

                case "type":
                    if let text = operation["text"] as? String {
                        self.simulateTyping(text: text)
                        Thread.sleep(forTimeInterval: 0.05)
                    }

                case "move":
                    if let x = operation["x"] as? Double,
                       let y = operation["y"] as? Double {
                        self.simulateMouseMove(to: CGPoint(x: x, y: y))
                        Thread.sleep(forTimeInterval: 0.05)
                    }

                default:
                    break
                }

                // 操作间隔
                if let delay = operation["delay"] as? Double, delay > 0 {
                    Thread.sleep(forTimeInterval: delay / 1000.0)
                }
            }

            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    private func simulateClick(at point: CGPoint, button: CGMouseButton) {
        let source = CGEventSource(stateID: .hidSystemState)

        let mouseDown = CGEvent(mouseEventSource: source, mouseType: button == .left ? .leftMouseDown : .rightMouseDown, mouseCursorPosition: point, mouseButton: button)
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: button == .left ? .leftMouseUp : .rightMouseUp, mouseCursorPosition: point, mouseButton: button)

        mouseDown?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01)
        mouseUp?.post(tap: .cghidEventTap)
    }

    private func simulateMouseMove(to point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
    }

    private func simulateScroll(deltaY: Double) {
        let source = CGEventSource(stateID: .hidSystemState)
        let scroll = CGEvent(scrollWheelEventSource: source, units: .pixel, wheelCount: 1, wheel1: Int32(deltaY))
        scroll?.post(tap: .cghidEventTap)
    }

    private func simulateKey(keyCode: Int, keyDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: keyDown)
        keyEvent?.post(tap: .cghidEventTap)
    }

    private func simulateTyping(text: String) {
        for char in text.unicodeScalars {
            let source = CGEventSource(stateID: .hidSystemState)

            // Mac 的字符输入比较复杂，需要将 Unicode 字符转换为 key events
            // 这里简化处理，实际使用可能需要更复杂的实现
            let unicodeChar = UniChar(char.value)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicodeChar])
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicodeChar])

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    // MARK: - Accessibility Check

    private func checkAccessibilityEnabled() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
