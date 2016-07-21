//
//  yas_audio_exception.cpp
//

#include <exception>
#include <string>
#include "yas_audio_exception.h"
#include "yas_audio_types.h"

using namespace yas;

void yas::raise_if_au_error(OSStatus const &err) {
    if (err != noErr) {
        throw std::runtime_error("audio unit error : " + std::to_string(err) + " - " + to_string(err));
    }
}
