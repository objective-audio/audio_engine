//
//  exception.cpp
//

#include <audio-engine/common/types.h>
#include <audio-engine/utils/exception.h>

#include <exception>
#include <string>

using namespace yas;

void yas::raise_if_raw_audio_error(OSStatus const &err) {
    if (err != noErr) {
        throw std::runtime_error("audio unit error : " + std::to_string(err) + " - " + to_string(err));
    }
}
