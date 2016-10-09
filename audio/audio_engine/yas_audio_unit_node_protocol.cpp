//
//  yas_audio_unit_node_protocol.cpp
//

#include "yas_audio_unit_node_protocol.h"

using namespace yas;

audio::engine::manageable_unit_node::manageable_unit_node(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::engine::manageable_unit_node::manageable_unit_node(std::nullptr_t) : protocol(nullptr) {
}

void audio::engine::manageable_unit_node::prepare_audio_unit() {
    impl_ptr<impl>()->prepare_audio_unit();
}

void audio::engine::manageable_unit_node::prepare_parameters() {
    impl_ptr<impl>()->prepare_parameters();
}

void audio::engine::manageable_unit_node::reload_audio_unit() {
    impl_ptr<impl>()->reload_audio_unit();
}
