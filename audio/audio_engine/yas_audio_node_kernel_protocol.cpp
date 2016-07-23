//
//  yas_audio_node_kernel_protocol.cpp
//

#include "yas_audio_node.h"

using namespace yas;

#pragma mark - manageable_kernel

audio::node::manageable_kernel::manageable_kernel(std::shared_ptr<impl> &&impl) : protocol(std::move(impl)) {
}

audio::node::manageable_kernel::manageable_kernel(std::nullptr_t) : protocol(nullptr) {
}

void audio::node::manageable_kernel::set_input_connections(audio::connection_wmap connections) {
    impl_ptr<impl>()->set_input_connections(std::move(connections));
}

void audio::node::manageable_kernel::set_output_connections(audio::connection_wmap connections) {
    impl_ptr<impl>()->set_output_connections(std::move(connections));
}
