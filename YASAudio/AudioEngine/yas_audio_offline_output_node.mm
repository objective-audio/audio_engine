//
//  yas_audio_offline_output_node.mm
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
    return _impl_ptr()->is_running();
}

audio_offline_output_node::start_result_t audio_offline_output_node::_start(const offline_render_f &callback_func,
                                                                            const offline_completion_f &completion_func)
{
    return _impl_ptr()->start(callback_func, completion_func);
}

void audio_offline_output_node::_stop()
{
    _impl_ptr()->stop();
}

std::shared_ptr<audio_offline_output_node::impl> audio_offline_output_node::_impl_ptr() const
{
    return impl_ptr<impl>();
}

std::string to_string(const audio_offline_output_node::start_error_t &error)
{
    switch (error) {
        case audio_offline_output_node::start_error_t::already_running:
            return "already_running";
        case audio_offline_output_node::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio_offline_output_node::start_error_t::connection_not_found:
            return "connection_not_found";
    }
}
