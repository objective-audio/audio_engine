//
//  yas_audio_offline_output_node.cpp
//

#include "yas_audio_offline_output_node.h"

using namespace yas;

#pragma mark - main

audio::offline_output_node::offline_output_node() : super_class(std::make_unique<impl>()) {
}

audio::offline_output_node::offline_output_node(std::nullptr_t) : super_class(nullptr) {
}

audio::offline_output_node::offline_output_node(std::shared_ptr<impl> const &impl) : super_class(impl) {
}

audio::offline_output_node::~offline_output_node() = default;

bool audio::offline_output_node::is_running() const {
    return impl_ptr<impl>()->is_running();
}

audio::manageable_offline_output_unit audio::offline_output_node::manageable_offline_output_unit() {
    return audio::manageable_offline_output_unit{impl_ptr<manageable_offline_output_unit::impl>()};
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
