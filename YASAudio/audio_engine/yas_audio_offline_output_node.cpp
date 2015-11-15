//
//  yas_audio_offline_output_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_offline_output_node.h"

using namespace yas;

#pragma mark - main

audio_offline_output_node::audio_offline_output_node()
    : super_class(std::make_unique<audio_offline_output_node::impl>())
{
}

audio_offline_output_node::audio_offline_output_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_offline_output_node::audio_offline_output_node(const std::shared_ptr<impl> &impl) : super_class(impl)
{
}

audio_offline_output_node::~audio_offline_output_node() = default;

bool audio_offline_output_node::is_running() const
{
    return impl_ptr<impl>()->is_running();
}

offline_start_result_t audio_offline_output_node::_start(const offline_render_f &callback_func,
                                                         const offline_completion_f &completion_func) const
{
    return impl_ptr<impl>()->start(callback_func, completion_func);
}

void audio_offline_output_node::_stop() const
{
    impl_ptr<impl>()->stop();
}

std::string to_string(const offline_start_error_t &error)
{
    switch (error) {
        case offline_start_error_t::already_running:
            return "already_running";
        case offline_start_error_t::prepare_failure:
            return "prepare_failure";
        case offline_start_error_t::connection_not_found:
            return "connection_not_found";
    }
}
