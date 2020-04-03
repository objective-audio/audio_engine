//
//  yas_audio_offline_io_core.cpp
//

#include "yas_audio_offline_io_core.h"
#include "yas_audio_offline_device.h"

using namespace yas;

audio::offline_io_core::offline_io_core(offline_device_ptr const &device) : _device(device) {
}

void audio::offline_io_core::initialize() {
    this->_update_kernel();

    if (!this->_device->output_format().has_value()) {
        return;
    }

    auto weak_core = this->_weak_io_core;

    auto task_lambda = [weak_core](task const &task) mutable {
        bool cancelled = false;
        uint32_t current_sample_time = 0;

        while (!cancelled) {
            auto core = weak_core.lock();
            if (!core) {
                cancelled = true;
                break;
            }

            auto kernel_opt = core->_kernel();
            if (!kernel_opt.has_value()) {
                cancelled = true;
                break;
            }
            auto const &kernel = kernel_opt.value();

            kernel->reset_buffers();

            auto const &buffer_opt = kernel->output_buffer;
            if (!buffer_opt.has_value()) {
                cancelled = true;
                break;
            }
            auto const &render_buffer = buffer_opt.value();

            audio::time when(current_sample_time, render_buffer->format().sample_rate());

            if (auto const handler = core->_render_handler()) {
                handler.value()({.output_buffer = render_buffer, .when = when});
            } else {
                cancelled = true;
                break;
            }

            auto const &offline_handler = core->_device->render_handler();
            if (offline_handler({.buffer = render_buffer, .when = when}) == continuation::abort) {
                break;
            }

            if (task.is_canceled()) {
                cancelled = true;
                break;
            }

            current_sample_time += render_buffer->frame_capacity();
        }

        dispatch_async(dispatch_get_main_queue(), [weak_core, cancelled]() {
            if (auto const core = weak_core.lock()) {
                core->_queue = std::nullopt;

                if (auto const &handler = core->_device->completion_handler()) {
                    handler.value()(cancelled);
                }
            }
        });
    };

    auto task = task::make_shared(std::move(task_lambda));
    this->_queue = task_queue{1};
    this->_queue->suspend();
    this->_queue->push_back(task);
}

void audio::offline_io_core::uninitialize() {
    this->stop();

    if (auto &queue = this->_queue) {
        queue->cancel_all();
        queue->wait_until_all_tasks_are_finished();
        this->_queue = std::nullopt;
    }

    if (auto const &handler = this->_device->completion_handler()) {
        handler.value()(true);
    }
}

void audio::offline_io_core::set_render_handler(std::optional<io_render_f> handler) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__render_handler = std::move(handler);
}

void audio::offline_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__maximum_frames = frames;
    this->_update_kernel();
}

bool audio::offline_io_core::start() {
    if (auto &queue = this->_queue) {
        queue->resume();
        return true;
    } else {
        return false;
    }
}

void audio::offline_io_core::stop() {
    if (auto &queue = this->_queue) {
        queue.value().cancel_all();
    }
}

std::optional<audio::pcm_buffer_ptr> const &audio::offline_io_core::input_buffer_on_render() const {
    static std::optional<audio::pcm_buffer_ptr> const _null_buffer = std::nullopt;
    return _null_buffer;
}

std::optional<audio::time_ptr> const &audio::offline_io_core::input_time_on_render() const {
    static std::optional<audio::time_ptr> const _null_time = std::nullopt;
    return _null_time;
}

void audio::offline_io_core::_prepare(offline_io_core_ptr const &core) {
    this->_weak_io_core = core;
}

std::optional<audio::io_render_f> audio::offline_io_core::_render_handler() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__render_handler;
}

void audio::offline_io_core::_set_kernel(std::optional<io_kernel_ptr> const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = std::nullopt;
    if (kernel) {
        this->__kernel = kernel;
    }
}

std::optional<audio::io_kernel_ptr> audio::offline_io_core::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::offline_io_core::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(std::nullopt);

    auto const &output_format = this->_device->output_format();

    if (!output_format) {
        return;
    }

    this->_set_kernel(io_kernel::make_shared(std::nullopt, output_format, this->__maximum_frames));
}

audio::offline_io_core_ptr audio::offline_io_core::make_shared(offline_device_ptr const &device) {
    auto shared = offline_io_core_ptr{new offline_io_core{device}};
    shared->_prepare(shared);
    return shared;
}