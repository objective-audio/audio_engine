//
//  yas_audio_device_io_extension_protocol.cpp
//

#include "yas_audio_device_io_extension_protocol.h"

using namespace yas;

audio::manageable_device_io_extension::manageable_device_io_extension(std::shared_ptr<impl> impl)
    : protocol(std::move(impl)) {
}

audio::manageable_device_io_extension::manageable_device_io_extension(std::nullptr_t) : protocol(nullptr) {
}

void audio::manageable_device_io_extension::add_device_io() {
    impl_ptr<impl>()->add_device_io();
}

void audio::manageable_device_io_extension::remove_device_io() {
    impl_ptr<impl>()->remove_device_io();
}

audio::device_io &audio::manageable_device_io_extension::device_io() const {
    return impl_ptr<impl>()->device_io();
}
