//
//  yas_audio_unit_protocol.cpp
//

#include "yas_audio_unit_protocol.h"

using namespace yas;

audio::manageable_unit::manageable_unit(std::shared_ptr<impl> impl) : protocol(impl) {
}

audio::manageable_unit::manageable_unit(std::nullptr_t) : protocol(nullptr) {
}

void audio::manageable_unit::initialize() {
    impl_ptr<impl>()->initialize();
}

void audio::manageable_unit::uninitialize() {
    impl_ptr<impl>()->uninitialize();
}

void audio::manageable_unit::set_graph_key(std::experimental::optional<uint8_t> const &key) {
    impl_ptr<impl>()->set_graph_key(key);
}

std::experimental::optional<uint8_t> const &audio::manageable_unit::graph_key() const {
    return impl_ptr<impl>()->graph_key();
}

void audio::manageable_unit::set_key(std::experimental::optional<uint16_t> const &key) {
    impl_ptr<impl>()->set_key(key);
}

std::experimental::optional<uint16_t> const &audio::manageable_unit::key() const {
    return impl_ptr<impl>()->key();
}
