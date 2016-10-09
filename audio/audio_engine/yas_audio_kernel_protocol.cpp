//
//  yas_audio_kernel_protocol.cpp
//

#include "yas_audio_node.h"

using namespace yas;

#pragma mark - manageable_kernel

audio::engine::manageable_kernel::manageable_kernel(std::shared_ptr<impl> &&impl) : protocol(std::move(impl)) {
}

audio::engine::manageable_kernel::manageable_kernel(std::nullptr_t) : protocol(nullptr) {
}

void audio::engine::manageable_kernel::set_input_connections(audio::engine::connection_wmap connections) {
    impl_ptr<impl>()->set_input_connections(std::move(connections));
}

void audio::engine::manageable_kernel::set_output_connections(audio::engine::connection_wmap connections) {
    impl_ptr<impl>()->set_output_connections(std::move(connections));
}
