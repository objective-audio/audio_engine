//
//  debug.cpp
//

#include <audio-engine/utils/debug.h>

#include <atomic>
#include <iostream>

using namespace yas;

namespace yas::audio {
static std::atomic<bool> _log_enabled;
}

void audio::set_log_enabled(bool const enabled) {
    _log_enabled.store(enabled);
}

void audio::log(std::string const &log) {
    if (_log_enabled.load()) {
        std::cout << log << std::endl;
    }
}
