//
//  yas_audio_offline_output_node_impl.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_offline_output_node.h"
#include "yas_audio_time.h"
#include "yas_stl_utils.h"
#include "yas_operation.h"

using namespace yas;

class audio_offline_output_node::impl::core
{
    using completion_function_map_t = std::map<UInt8, offline_completion_f>;

   public:
    operation_queue queue = nullptr;

    core() : queue(nullptr), _completion_functions()
    {
    }

    ~core()
    {
        if (queue) {
            queue.cancel_all_operations();
        }
    }

    const std::experimental::optional<UInt8> push_completion_function(const offline_completion_f &function)
    {
        if (!function) {
            return nullopt;
        }

        auto key = min_empty_key(_completion_functions);
        if (key) {
            _completion_functions.insert(std::make_pair(*key, function));
        }
        return key;
    }

    const std::experimental::optional<offline_completion_f> pull_completion_function(UInt8 key)
    {
        if (_completion_functions.count(key) > 0) {
            auto func = _completion_functions.at(key);
            _completion_functions.erase(key);
            return func;
        } else {
            return nullopt;
        }
    }

    completion_function_map_t pull_completion_functions()
    {
        auto map = _completion_functions;
        _completion_functions.clear();
        return map;
    }

   private:
    completion_function_map_t _completion_functions;
};

audio_offline_output_node::impl::impl()
    : super_class::impl(), _core(std::make_unique<audio_offline_output_node::impl::core>())
{
}

audio_offline_output_node::impl::~impl() = default;

offline_start_result_t audio_offline_output_node::impl::start(const offline_render_f &render_func,
                                                              const offline_completion_f &completion_func)
{
    if (_core->queue) {
        return offline_start_result_t(offline_start_error_t::already_running);
    } else if (auto connection = input_connection(0)) {
        std::experimental::optional<UInt8> key;
        if (completion_func) {
            key = _core->push_completion_function(completion_func);
            if (!key) {
                return offline_start_result_t(offline_start_error_t::prepare_failure);
            }
        }

        yas::audio_pcm_buffer render_buffer(connection.format(), 1024);

        yas::operation operation([weak_node = weak_node(), render_buffer = std::move(render_buffer), render_func, key](
            const yas::operation &operation) mutable {
            bool cancelled = false;
            UInt32 current_sample_time = 0;
            bool stop = false;

            while (!stop) {
                audio_time when(current_sample_time, render_buffer.format().sample_rate());
                auto offline_node = weak_node.lock();
                if (!offline_node) {
                    cancelled = true;
                    break;
                }

                auto kernel = offline_node.impl_ptr<impl>()->kernel_cast();
                if (!kernel) {
                    cancelled = true;
                    break;
                }

                auto connection_on_block = kernel->input_connection(0);
                if (!connection_on_block) {
                    cancelled = true;
                    break;
                }

                auto format = connection_on_block.format();
                if (format != render_buffer.format()) {
                    cancelled = true;
                    break;
                }

                render_buffer.reset();

                if (auto source_node = connection_on_block.source_node()) {
                    source_node.render(render_buffer, connection_on_block.source_bus(), when);
                }

                if (render_func) {
                    render_func(render_buffer, when, stop);
                }

                if (operation.is_canceled()) {
                    cancelled = true;
                    break;
                }

                current_sample_time += 1024;
            }

            auto completion_lambda = [weak_node, cancelled, key]() {
                if (auto offline_node = weak_node.lock()) {
                    std::experimental::optional<offline_completion_f> node_completion_func;
                    if (key) {
                        node_completion_func = offline_node.impl_ptr<impl>()->_core->pull_completion_function(*key);
                    }

                    offline_node.impl_ptr<impl>()->_core->queue = nullptr;

                    if (node_completion_func) {
                        (*node_completion_func)(cancelled);
                    }
                }
            };

            dispatch_async(dispatch_get_main_queue(), completion_lambda);
        });

        _core->queue = yas::operation_queue{};
        _core->queue.add_operation(operation);
    } else {
        return offline_start_result_t(offline_start_error_t::connection_not_found);
    }
    return offline_start_result_t(nullptr);
}

void audio_offline_output_node::impl::stop()
{
    auto completion_functions = _core->pull_completion_functions();

    if (auto queue = _core->queue) {
        queue.cancel_all_operations();
        _core->queue = nullptr;
    }

    for (auto &pair : completion_functions) {
        auto &func = pair.second;
        if (func) {
            func(true);
        }
    }
}

void audio_offline_output_node::impl::reset()
{
    stop();
    super_class::reset();
}

UInt32 audio_offline_output_node::impl::output_bus_count() const
{
    return 0;
}

UInt32 audio_offline_output_node::impl::input_bus_count() const
{
    return 1;
}

weak<audio_offline_output_node> audio_offline_output_node::impl::weak_node() const
{
    return node().cast<audio_offline_output_node>();
}

bool audio_offline_output_node::impl::is_running() const
{
    return !!_core->queue;
}
