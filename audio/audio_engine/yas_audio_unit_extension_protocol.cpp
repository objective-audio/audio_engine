//
//  yas_audio_unit_extension_protocol.cpp
//

#include "yas_audio_unit_extension_protocol.h"

using namespace yas;

audio::manageable_unit_extension::manageable_unit_extension(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::manageable_unit_extension::manageable_unit_extension(std::nullptr_t) : protocol(nullptr) {
}

void audio::manageable_unit_extension::prepare_audio_unit() {
    impl_ptr<impl>()->prepare_audio_unit();
}

void audio::manageable_unit_extension::prepare_parameters() {
    impl_ptr<impl>()->prepare_parameters();
}

void audio::manageable_unit_extension::reload_audio_unit() {
    impl_ptr<impl>()->reload_audio_unit();
}
