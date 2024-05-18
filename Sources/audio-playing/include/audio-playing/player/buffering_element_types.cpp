//
//  buffering_element_types.cpp
//

#include "buffering_element_types.h"

using namespace yas;
using namespace yas::playing;

std::string yas::to_string(playing::audio_buffering_element_state const &state) {
    switch (state) {
        case playing::audio_buffering_element_state::initial:
            return "initial";
        case playing::audio_buffering_element_state::writable:
            return "writable";
        case playing::audio_buffering_element_state::readable:
            return "readable";
    }
}

std::ostream &operator<<(std::ostream &os, yas::playing::audio_buffering_element_state const &value) {
    os << to_string(value);
    return os;
}
