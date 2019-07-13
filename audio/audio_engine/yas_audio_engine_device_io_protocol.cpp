//
//  yas_audio_device_io_protocol.cpp
//

#include "yas_audio_engine_device_io_protocol.h"

using namespace yas;

audio::engine::manageable_device_io::manageable_device_io(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::engine::manageable_device_io::manageable_device_io(std::nullptr_t) : protocol(nullptr) {
}

void audio::engine::manageable_device_io::add_device_io() {
    impl_ptr<impl>()->add_device_io();
}

void audio::engine::manageable_device_io::remove_device_io() {
    impl_ptr<impl>()->remove_device_io();
}

std::shared_ptr<audio::device_io> &audio::engine::manageable_device_io::device_io() const {
    return impl_ptr<impl>()->device_io();
}
