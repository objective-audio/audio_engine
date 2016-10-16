//
//  yas_audio_engine_au_protocol.cpp
//

#include "yas_audio_engine_au_protocol.h"

using namespace yas;

audio::engine::manageable_au::manageable_au(std::shared_ptr<impl> impl) : protocol(std::move(impl)) {
}

audio::engine::manageable_au::manageable_au(std::nullptr_t) : protocol(nullptr) {
}

void audio::engine::manageable_au::prepare_unit() {
    impl_ptr<impl>()->prepare_unit();
}

void audio::engine::manageable_au::prepare_parameters() {
    impl_ptr<impl>()->prepare_parameters();
}

void audio::engine::manageable_au::reload_unit() {
    impl_ptr<impl>()->reload_unit();
}
