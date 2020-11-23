//
//  yas_audio_exception.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>

namespace yas {
void raise_if_raw_audio_error(OSStatus const &err);
}
