//
//  yas_audio_offline_output_node_impl.mm
//

#include "yas_audio_offline_output_node.h"
#include "yas_audio_time.h"
#include "yas_operation.h"
#include "yas_stl_utils.h"

using namespace yas;

struct audio::offline_output_node::impl::core {
    using completion_function_map_t = std::map<uint8_t, offline_completion_f>;

    operation_queue queue;
    audio::node::observer_t _reset_observer;

    core() : queue(nullptr), _completion_functions() {
    }

    ~core() = default;

    std::experimental::optional<uint8_t> const push_completion_function(offline_completion_f &&function) {
        if (!function) {
            return nullopt;
        }

        auto key = min_empty_key(_completion_functions);
        if (key) {
            _completion_functions.insert(std::make_pair(*key, std::move(function)));
        }
        return key;
    }

    std::experimental::optional<offline_completion_f> const pull_completion_function(uint8_t key) {
        if (_completion_functions.count(key) > 0) {
            auto func = _completion_functions.at(key);
            _completion_functions.erase(key);
            return std::move(func);
        } else {
            return nullopt;
        }
    }

    completion_function_map_t pull_completion_functions() {
        auto map = _completion_functions;
        _completion_functions.clear();
        return map;
    }

   private:
    completion_function_map_t _completion_functions;
};

audio::offline_output_node::impl::impl()
    : node::impl::impl(), _core(std::make_unique<audio::offline_output_node::impl::core>()) {
}

audio::offline_output_node::impl::~impl() = default;

void audio::offline_output_node::impl::prepare(offline_output_node const &node) {
    _core->_reset_observer =
        subject().make_observer(audio::node::method::will_reset, [weak_node = to_weak(node)](auto const &) {
            if (auto node = weak_node.lock()) {
                node.impl_ptr<audio::offline_output_node::impl>()->will_reset();
            }
        });
}

void audio::offline_output_node::impl::will_reset() {
    stop();
}

audio::offline_start_result_t audio::offline_output_node::impl::start(offline_render_f &&render_func,
                                                                      offline_completion_f &&completion_func) {
    if (_core->queue) {
        return offline_start_result_t(offline_start_error_t::already_running);
    } else if (auto connection = input_connection(0)) {
        std::experimental::optional<uint8_t> key;
        if (completion_func) {
            key = _core->push_completion_function(std::move(completion_func));
            if (!key) {
                return offline_start_result_t(offline_start_error_t::prepare_failure);
            }
        }

        audio::pcm_buffer render_buffer(connection.format(), 1024);

        auto weak_node = to_weak(cast<offline_output_node>());
        auto operation_lambda =
            [weak_node, render_buffer, render_func = std::move(render_func), key](operation const &op) mutable {
            bool cancelled = false;
            uint32_t current_sample_time = 0;
            bool stop = false;

            while (!stop) {
                audio::time when(current_sample_time, render_buffer.format().sample_rate());
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

                auto connection_on_block = kernel.input_connection(0);
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
                    render_func({.buffer = render_buffer, .when = when, .out_stop = stop});
                }

                if (op.is_canceled()) {
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
        };

        operation operation{std::move(operation_lambda)};
        _core->queue = operation_queue{1};
        _core->queue.push_back(operation);
    } else {
        return offline_start_result_t(offline_start_error_t::connection_not_found);
    }
    return offline_start_result_t(nullptr);
}

void audio::offline_output_node::impl::stop() {
    auto completion_functions = _core->pull_completion_functions();

    if (auto &queue = _core->queue) {
        queue.cancel();
        queue.wait_until_all_operations_are_finished();
        _core->queue = nullptr;
    }

    for (auto &pair : completion_functions) {
        auto &func = pair.second;
        if (func) {
            func(true);
        }
    }
}

uint32_t audio::offline_output_node::impl::output_bus_count() const {
    return 0;
}

uint32_t audio::offline_output_node::impl::input_bus_count() const {
    return 1;
}

bool audio::offline_output_node::impl::is_running() const {
    return _core->queue != nullptr;
}
