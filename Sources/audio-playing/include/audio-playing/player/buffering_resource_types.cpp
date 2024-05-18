//
//  buffering_resource_types.cpp
//

#include "buffering_resource_types.h"

using namespace yas;
using namespace yas::playing;

std::string yas::to_string(playing::audio_buffering_setup_state const state) {
    switch (state) {
        case playing::audio_buffering_setup_state::initial:
            return "initial";
        case playing::audio_buffering_setup_state::creating:
            return "creating";
        case playing::audio_buffering_setup_state::rendering:
            return "rendering";
    }
}

std::string yas::to_string(playing::audio_buffering_rendering_state const state) {
    switch (state) {
        case playing::audio_buffering_rendering_state::waiting:
            return "waiting";
        case playing::audio_buffering_rendering_state::all_writing:
            return "all_writing";
        case playing::audio_buffering_rendering_state::advancing:
            return "advancing";
    }
}

std::ostream &operator<<(std::ostream &os, yas::playing::audio_buffering_setup_state const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::playing::audio_buffering_rendering_state const &value) {
    os << to_string(value);
    return os;
}
