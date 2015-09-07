//
//  yas_audio_offline_output_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_offline_output_node.h"
#include "yas_audio_time.h"
#include "yas_objc_container.h"
#include "yas_stl_utils.h"
#include <map>
#include <Foundation/Foundation.h>

using namespace yas;

class audio_offline_output_node::impl
{
    using completion_function_map = std::map<uint8_t, completion_f>;

   public:
    std::weak_ptr<audio_offline_output_node> weak_node;
    objc_strong_container queue_container;

    impl() : queue_container(nil), _completion_functions()
    {
    }

    const std::experimental::optional<uint8_t> push_completion_function(const completion_f &function)
    {
        if (!function) {
            return std::experimental::nullopt;
        }

        auto key = min_empty_key(_completion_functions);
        if (key) {
            _completion_functions.insert(std::make_pair(*key, function));
        }
        return key;
    }

    const std::experimental::optional<completion_f> pull_completion_function(uint8_t key)
    {
        if (_completion_functions.count(key) > 0) {
            auto func = _completion_functions.at(key);
            _completion_functions.erase(key);
            return func;
        } else {
            return std::experimental::nullopt;
        }
    }

    completion_function_map pull_completion_functions()
    {
        auto map = _completion_functions;
        _completion_functions.clear();
        return map;
    }

   private:
    completion_function_map _completion_functions;
};

audio_offline_output_node_sptr audio_offline_output_node::create()
{
    auto node = audio_offline_output_node_sptr(new audio_offline_output_node());
    node->_impl->weak_node = node;
    return node;
}

audio_offline_output_node::audio_offline_output_node() : audio_node(), _impl(std::make_unique<impl>())
{
}

audio_offline_output_node::~audio_offline_output_node()
{
    if (auto queue_container = _impl->queue_container) {
        NSOperationQueue *operationQueue = queue_container.object();
        [operationQueue cancelAllOperations];
    }
}

UInt32 audio_offline_output_node::output_bus_count() const
{
    return 0;
}

UInt32 audio_offline_output_node::input_bus_count() const
{
    return 1;
}

audio_offline_output_node::start_result audio_offline_output_node::_start(const render_f &render_func,
                                                                          const completion_f &completion_func)
{
    if (_impl->queue_container) {
        return start_result(start_error_t::already_running);
    } else if (auto connection = input_connection(0)) {
        std::experimental::optional<uint8_t> key;
        if (completion_func) {
            key = _impl->push_completion_function(completion_func);
            if (!key) {
                return start_result(start_error_t::prepare_failure);
            }
        }

        auto weak_node = _impl->weak_node;
        auto render_buffer = yas::audio_pcm_buffer::create(connection->format(), 1024);

        NSBlockOperation *blockOperation = [[NSBlockOperation alloc] init];
        auto operation_container = objc_weak_container::create(blockOperation);

        auto operation_lambda = [weak_node, operation_container, render_buffer, render_func, key]() {
            bool cancelled = false;
            UInt32 current_sample_time = 0;
            bool stop = false;

            while (!stop) {
                auto when = audio_time::create(current_sample_time, render_buffer->format()->sample_rate());
                auto offline_node = weak_node.lock();
                if (!offline_node) {
                    cancelled = true;
                    break;
                }

                auto node_core = offline_node->node_core();
                if (!node_core) {
                    cancelled = true;
                    break;
                }

                auto connection_on_block = node_core->input_connection(0);
                if (!connection_on_block) {
                    cancelled = true;
                    break;
                }

                auto format = connection_on_block->format();
                if (!format || *format != *render_buffer->format()) {
                    cancelled = true;
                    break;
                }

                render_buffer->reset();

                if (auto source_node = connection_on_block->source_node()) {
                    source_node->render(render_buffer, connection_on_block->source_bus(), when);
                }

                if (render_func) {
                    render_func(render_buffer, when, stop);
                }

                if (auto strong_operation_container = operation_container->lock()) {
                    NSOperation *operation = strong_operation_container.object();
                    if (!operation || operation.isCancelled) {
                        cancelled = true;
                        break;
                    }
                }

                current_sample_time += 1024;
            }

            auto completion_lambda = [weak_node, cancelled, key]() {
                if (auto offline_node = weak_node.lock()) {
                    std::experimental::optional<completion_f> node_completion_func;
                    if (key) {
                        node_completion_func = offline_node->_impl->pull_completion_function(*key);
                    }

                    offline_node->_impl->queue_container.set_object(nil);

                    if (node_completion_func) {
                        (*node_completion_func)(cancelled);
                    }
                }
            };

            dispatch_async(dispatch_get_main_queue(), completion_lambda);
        };

        [blockOperation addExecutionBlock:operation_lambda];

        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        queue.maxConcurrentOperationCount = 1;
        _impl->queue_container.set_object(queue);

        [queue addOperation:blockOperation];

        YASRelease(blockOperation);
        YASRelease(queue);
    } else {
        return start_result(start_error_t::connection_not_found);
    }
    return start_result(nullptr);
}

void audio_offline_output_node::_stop()
{
    auto completion_functions = _impl->pull_completion_functions();

    if (auto queue_container = _impl->queue_container) {
        NSOperationQueue *queue = queue_container.object();
        [queue cancelAllOperations];
        [queue waitUntilAllOperationsAreFinished];
        _impl->queue_container.set_object(nil);
    }

    for (auto &pair : completion_functions) {
        auto &func = pair.second;
        if (func) {
            func(true);
        }
    }
}

bool audio_offline_output_node::is_running() const
{
    return !!_impl->queue_container;
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
