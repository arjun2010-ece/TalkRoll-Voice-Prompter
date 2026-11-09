#include "include/talkroll_window/talkroll_window_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "talkroll_window_plugin.h"

void TalkRollWindowPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  talkroll_window::TalkRollWindowPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
