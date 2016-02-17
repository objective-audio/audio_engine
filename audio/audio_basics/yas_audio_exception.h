//
//  yas_audio_exception.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>

namespace yas {
void raise_if_au_error(OSStatus const &err);
}
