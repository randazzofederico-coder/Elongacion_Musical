//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <just_audio_windows/just_audio_windows_plugin.h>
#include <native_audio_engine/native_audio_engine_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  JustAudioWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("JustAudioWindowsPlugin"));
  NativeAudioEnginePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("NativeAudioEnginePluginCApi"));
}
