//
//  yas_audio_offline_output_protocol.cpp
//

#include "yas_audio_engine_offline_output_protocol.h"

using namespace yas;

audio::engine::manageable_offline_output_unit::manageable_offline_output_unit(std::shared_ptr<impl> impl)
    : protocol(std::move(impl)) {
}

audio::engine::manageable_offline_output_unit::manageable_offline_output_unit(std::nullptr_t) : protocol(nullptr) {
}

audio::engine::offline_start_result_t audio::engine::manageable_offline_output_unit::start(offline_render_f &&render_handler,
                                                                           offline_completion_f &&completion_handler) {
    return impl_ptr<impl>()->start(std::move(render_handler), std::move(completion_handler));
}

void audio::engine::manageable_offline_output_unit::stop() {
    impl_ptr<impl>()->stop();
}
