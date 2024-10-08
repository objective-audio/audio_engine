//
//  debug.cpp
//

#include <audio-engine/utils/debug.h>

#if DEBUG

#include <iostream>

using namespace yas;

namespace yas::audio {
static bool _log_enabled = false;
}

void audio::set_log_enabled(bool const enabled) {
    _log_enabled = enabled;
}

void audio::log(std::string const &log) {
    if (_log_enabled) {
        std::cout << log << std::endl;
    }
}

#endif
