#ifndef AUTOMATION_PLUGIN_H_
#define AUTOMATION_PLUGIN_H_

#include <windows.h>
#include <UIAutomation.h>
#include <flutter/plugin_registrar.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <vector>
#include <map>
#include <string>

// Automation plugin for Windows - provides UI automation and input simulation
class AutomationPlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrar* registrar);

    AutomationPlugin();
    virtual ~AutomationPlugin();

    // Plugin methods
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

private:
    // Recording
    bool StartRecording();
    bool StopRecording();
    std::vector<std::map<std::string, flutter::EncodableValue>> GetRecordedEvents();

    // Playback
    bool Play(const std::vector<std::map<std::string, flutter::EncodableValue>>& operations);

    // Element finding
    std::map<std::string, flutter::EncodableValue> FindElementAt(double x, double y);
    bool IsUIAEnabled();

    // Input simulation
    void SimulateClick(double x, double y, bool rightButton = false);
    void SimulateMouseMove(double x, double y);
    void SimulateScroll(double deltaY);
    void SimulateKey(int keyCode, bool keyDown);
    void SimulateType(const std::wstring& text);

    // UIA helpers
    IUIAutomation* GetUIAutomation();

    // Member variables
    IUIAutomation* uia_;
    bool isRecording_;
    bool isPlaying_;
    std::vector<std::map<std::string, flutter::EncodableValue>> recordedEvents_;
    DWORD recordingStartTime_;
    HHOOK mouseHook_;
    HHOOK keyboardHook_;
    static LRESULT CALLBACK MouseHookProc(int nCode, WPARAM wParam, LPARAM lParam);
    static LRESULT CALLBACK KeyboardHookProc(int nCode, WPARAM wParam, LPARAM lParam);
    static AutomationPlugin* currentInstance_;
};

#endif  // AUTOMATION_PLUGIN_H_
