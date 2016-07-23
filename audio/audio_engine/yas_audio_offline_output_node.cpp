//
//  yas_audio_offline_output_node.cpp
//

#include "yas_audio_offline_output_node.h"

using namespace yas;

#pragma mark - main

audio::offline_output_node::offline_output_node() : node(std::make_unique<impl>()) {
}

audio::offline_output_node::offline_output_node(std::nullptr_t) : node(nullptr) {
}

audio::offline_output_node::offline_output_node(std::shared_ptr<impl> const &impl) : node(impl) {
}

audio::offline_output_node::~offline_output_node() = default;

bool audio::offline_output_node::is_running() const {
    return impl_ptr<impl>()->is_running();
}

audio::manageable_offline_output_unit &audio::offline_output_node::manageable() {
    if (!_manageable) {
        _manageable = audio::manageable_offline_output_unit{impl_ptr<manageable_offline_output_unit::impl>()};
    }
    return _manageable;
}

std::string yas::to_string(audio::offline_start_error_t const &error) {
    switch (error) {
        case audio::offline_start_error_t::already_running:
            return "already_running";
        case audio::offline_start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::offline_start_error_t::connection_not_found:
            return "connection_not_found";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::offline_start_error_t const &value) {
    os << to_string(value);
    return os;
}
