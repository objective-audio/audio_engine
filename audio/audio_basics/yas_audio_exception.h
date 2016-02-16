//
//  yas_audio_exception.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>

namespace yas {
void raise_if_au_error(OSStatus const &err);
}
