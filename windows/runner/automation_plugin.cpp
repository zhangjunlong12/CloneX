#include "automation_plugin.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>
#include <Windows.h>
#include <WinUser.h>
#include <Ole2.h>
#include <iostream>

// Link with UIAutomation core library
#pragma comment(lib, "UIAutomationCore.lib")

AutomationPlugin* AutomationPlugin::currentInstance_ = nullptr;

void AutomationPlugin::RegisterWithRegistrar(flutter::PluginRegistrar* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel>(
        registrar->messenger(),
        "com.clonex/windows_automation",
        &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<AutomationPlugin>();

    channel->SetMethodCallHandler(
        [plugin = plugin.get()](const auto& call, auto result) {
            plugin->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
}

AutomationPlugin::AutomationPlugin()
    : uia_(nullptr),
      isRecording_(false),
      isPlaying_(false),
      mouseHook_(nullptr),
      keyboardHook_(nullptr) {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    CoCreateInstance(
        CLSID_CUIAutomation,
        nullptr,
        CLSCTX_INPROC_SERVER,
        IID_IUIAutomation,
        (void**)&uia_);
}

AutomationPlugin::~AutomationPlugin() {
    if (mouseHook_) UnhookWindowsHookEx(mouseHook_);
    if (keyboardHook_) UnhookWindowsHookEx(keyboardHook_);
    if (uia_) uia_->Release();
    CoUninitialize();
}

void AutomationPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const std::string& method = call.method_name();

    if (method == "startRecording") {
        bool success = StartRecording();
        result->Success(flutter::EncodableValue(success));
    } else if (method == "stopRecording") {
        bool success = StopRecording();
        result->Success(flutter::EncodableValue(success));
    } else if (method == "getRecordedEvents") {
        auto events = GetRecordedEvents();
        result->Success(flutter::EncodableValue(events));
    } else if (method == "play") {
        const auto* args = std::get_if<flutter::EncodableList>(call.arguments());
        if (args) {
            std::vector<std::map<std::string, flutter::EncodableValue>> operations;
            for (const auto& arg : *args) {
                const auto& map = std::get<flutter::EncodableMap>(arg);
                std::map<std::string, flutter::EncodableValue> op;
                for (const auto& pair : map) {
                    std::string key = std::get<std::string>(pair.first);
                    op[key] = pair.second;
                }
                operations.push_back(op);
            }
            bool success = Play(operations);
            result->Success(flutter::EncodableValue(success));
        } else {
            result->Error("INVALID_ARGS", "Expected array of operations");
        }
    } else if (method == "findElementAt") {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (args) {
            double x = 0, y = 0;
            for (const auto& pair : *args) {
                std::string key = std::get<std::string>(pair.first);
                if (key == "x") x = std::get<double>(pair.second);
                if (key == "y") y = std::get<double>(pair.second);
            }
            auto element = FindElementAt(x, y);
            result->Success(flutter::EncodableValue(element));
        } else {
            result->Error("INVALID_ARGS", "Expected x and y");
        }
    } else if (method == "isAccessibilityEnabled") {
        bool enabled = IsUIAEnabled();
        result->Success(flutter::EncodableValue(enabled));
    } else {
        result->NotImplemented();
    }
}

bool AutomationPlugin::StartRecording() {
    if (isRecording_) return false;

    recordedEvents_.clear();
    recordingStartTime_ = GetTickCount();
    isRecording_ = true;

    // Store instance for hook callbacks
    currentInstance_ = this;

    // Note: Hooks would require a message loop to process
    // For now, we rely on polling-based recording in the playback

    return true;
}

bool AutomationPlugin::StopRecording() {
    if (!isRecording_) return false;
    isRecording_ = false;
    currentInstance_ = nullptr;
    return true;
}

std::vector<std::map<std::string, flutter::EncodableValue>>
AutomationPlugin::GetRecordedEvents() {
    return recordedEvents_;
}

bool AutomationPlugin::Play(
    const std::vector<std::map<std::string, flutter::EncodableValue>>& operations) {

    if (isPlaying_) return false;
    isPlaying_ = true;

    for (const auto& op : operations) {
        if (!isPlaying_) break;

        std::string type;
        double x = 0, y = 0, deltaY = 0;
        int keyCode = 0;
        std::wstring text;

        for (const auto& pair : op) {
            std::string key = pair.first;
            if (key == "type") {
                type = std::get<std::string>(pair.second);
            } else if (key == "x") {
                x = std::get<double>(pair.second);
            } else if (key == "y") {
                y = std::get<double>(pair.second);
            } else if (key == "deltaY") {
                deltaY = std::get<double>(pair.second);
            } else if (key == "keyCode") {
                keyCode = std::get<int>(pair.second);
            } else if (key == "text") {
                text = std::get<std::string>(pair.second);
            }
        }

        if (type == "click" || type == "mouseDown") {
            SimulateClick(x, y, false);
            Sleep(50);
        } else if (type == "rightClick") {
            SimulateClick(x, y, true);
            Sleep(50);
        } else if (type == "scroll") {
            SimulateScroll(deltaY);
            Sleep(100);
        } else if (type == "keyDown" || type == "keyUp") {
            SimulateKey(keyCode, type == "keyDown");
            Sleep(20);
        } else if (type == "type") {
            SimulateType(text);
            Sleep(50);
        } else if (type == "move") {
            SimulateMouseMove(x, y);
            Sleep(50);
        }

        // Apply delay between operations
        auto delayIt = op.find("delay");
        if (delayIt != op.end()) {
            double delay = std::get<double>(delayIt->second);
            if (delay > 0 && delay < 5000) {
                Sleep((DWORD)delay);
            }
        }
    }

    isPlaying_ = false;
    return true;
}

std::map<std::string, flutter::EncodableValue>
AutomationPlugin::FindElementAt(double x, double y) {
    std::map<std::string, flutter::EncodableValue> info;

    if (!uia_) return info;

    IUIAutomationElement* element = nullptr;
    POINT pt = {(LONG)x, (LONG)y};
    HRESULT hr = uia_->ElementFromPoint(pt, &element);

    if (SUCCEEDED(hr) && element) {
        BSTR name = nullptr;
        BSTR role = nullptr;
        BSTR value = nullptr;
        BSTR desc = nullptr;

        element->get_CurrentName(&name);
        element->get_CurrentLocalizedControlType(&role);
        element->get_CurrentValue(&value);
        element->get_CurrentHelpText(&desc);

        if (name) {
            info["name"] = std::string(name, SysStringLen(name));
            SysFreeString(name);
        }
        if (role) {
            info["role"] = std::string(role, SysStringLen(role));
            SysFreeString(role);
        }
        if (value) {
            info["value"] = std::string(value, SysStringLen(value));
            SysFreeString(value);
        }
        if (desc) {
            info["description"] = std::string(desc, SysStringLen(desc));
            SysFreeString(desc);
        }

        // Get bounds
        RECT rect;
        if (SUCCEEDED(element->get_CurrentBoundingRectangle(&rect))) {
            info["bounds"] = flutter::EncodableValue(flutter::EncodableMap{
                {"x", (double)rect.left},
                {"y", (double)rect.top},
                {"width", (double)(rect.right - rect.left)},
                {"height", (double)(rect.bottom - rect.top)}
            });
        }

        element->Release();
    }

    return info;
}

bool AutomationPlugin::IsUIAEnabled() {
    if (!uia_) return false;

    IUIAutomationElement* root = nullptr;
    HRESULT hr = uia_->GetRootElement(&root);
    if (FAILED(hr) || !root) return false;

    root->Release();
    return true;
}

IUIAutomation* AutomationPlugin::GetUIAutomation() {
    return uia_;
}

void AutomationPlugin::SimulateClick(double x, double y, bool rightButton) {
    // Convert to screen coordinates (for absolute positioning)
    INPUT inputs[2] = {};

    // Mouse down
    inputs[0].type = INPUT_MOUSE;
    inputs[0].mi.dx = (LONG)x;
    inputs[0].mi.dy = (LONG)y;
    inputs[0].mi.mouseData = 0;
    inputs[0].mi.dwFlags = MOUSEEVENTF_ABSOLUTE |
                           (rightButton ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_LEFTDOWN);

    // Mouse up
    inputs[1].type = INPUT_MOUSE;
    inputs[1].mi.dx = (LONG)x;
    inputs[1].mi.dy = (LONG)y;
    inputs[1].mi.mouseData = 0;
    inputs[1].mi.dwFlags = MOUSEEVENTF_ABSOLUTE |
                           (rightButton ? MOUSEEVENTF_RIGHTUP : MOUSEEVENTF_LEFTUP);

    SendInput(2, inputs, sizeof(INPUT));
}

void AutomationPlugin::SimulateMouseMove(double x, double y) {
    INPUT input = {};
    input.type = INPUT_MOUSE;
    input.mi.dx = (LONG)x;
    input.mi.dy = (LONG)y;
    input.mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE;
    SendInput(1, &input, sizeof(INPUT));
}

void AutomationPlugin::SimulateScroll(double deltaY) {
    INPUT input = {};
    input.type = INPUT_MOUSE;
    input.mi.mouseData = (DWORD)(-deltaY * 120);  // Scroll delta (positive = up)
    input.mi.dwFlags = MOUSEEVENTF_WHEEL;
    SendInput(1, &input, sizeof(INPUT));
}

void AutomationPlugin::SimulateKey(int keyCode, bool keyDown) {
    INPUT input = {};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = (WORD)keyCode;
    input.ki.dwFlags = keyDown ? 0 : KEYEVENTF_KEYUP;
    input.ki.wScan = 0;
    SendInput(1, &input, sizeof(INPUT));
}

void AutomationPlugin::SimulateType(const std::wstring& text) {
    for (wchar_t c : text) {
        INPUT inputs[2] = {};

        // Key down
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki.wVk = 0;
        inputs[0].ki.wScan = c;
        inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;

        // Key up
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].ki.wVk = 0;
        inputs[1].ki.wScan = c;
        inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

        SendInput(2, inputs, sizeof(INPUT));
        Sleep(20);
    }
}

LRESULT CALLBACK AutomationPlugin::MouseHookProc(
    int nCode, WPARAM wParam, LPARAM lParam) {
    if (currentInstance_ && currentInstance_->isRecording_) {
        // Record mouse events
        // Note: Implementation would process MSLLHOOKSTRUCT
    }
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
}

LRESULT CALLBACK AutomationPlugin::KeyboardHookProc(
    int nCode, WPARAM wParam, LPARAM lParam) {
    if (currentInstance_ && currentInstance_->isRecording_) {
        // Record keyboard events
        // Note: Implementation would process KBDLLHOOKSTRUCT
    }
    return CallNextHookEx(nullptr, nCode, wParam, lParam);
}
