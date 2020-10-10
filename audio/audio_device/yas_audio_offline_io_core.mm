//
//  yas_audio_offline_io_core.cpp
//

#include "yas_audio_offline_io_core.h"
#include "yas_audio_offline_device.h"

using namespace yas;

struct audio::offline_io_core::render_context {
    std::optional<task_queue> queue = std::nullopt;
};

audio::offline_io_core::offline_io_core(offline_device_ptr const &device)
    : _device(device), _render_context(std::make_shared<render_context>()) {
}

void audio::offline_io_core::initialize() {
    this->_kernel = this->_make_kernel();
}

void audio::offline_io_core::uninitialize() {
    this->stop();

    this->_kernel = std::nullopt;
}

void audio::offline_io_core::set_render_handler(std::optional<io_render_f> handler) {
    this->_render_handler = std::move(handler);
}

void audio::offline_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    this->_maximum_frames = frames;
}

bool audio::offline_io_core::start() {
    if (this->_render_context->queue) {
        return false;
    }

    if (!this->_kernel.has_value()) {
        return false;
    }

    auto task_lambda = [kernel = this->_kernel.value(), render_context = this->_render_context,
                        offline_handler = this->_device->render_handler(),
                        completion = this->_device->completion_handler()](task const &task) mutable {
        bool cancelled = false;
        uint32_t current_sample_time = 0;

        while (!cancelled) {
            kernel->reset_buffers();

            auto const &render_buffer = kernel->output_buffer;
            if (!render_buffer) {
                cancelled = true;
                break;
            }

            audio::time time(current_sample_time, render_buffer->format().sample_rate());

            kernel->render_handler({.output_buffer = render_buffer.get(),
                                    .output_time = time,
                                    .input_buffer = nullptr,
                                    .input_time = audio::null_time_opt});

            if (offline_handler({.output_buffer = render_buffer, .output_time = time}) == continuation::abort) {
                break;
            }

            if (task.is_canceled()) {
                cancelled = true;
                break;
            }

            current_sample_time += render_buffer->frame_capacity();
        }

        dispatch_async(dispatch_get_main_queue(), [cancelled, render_context, completion]() {
            render_context->queue = std::nullopt;

            if (auto const &handler = completion) {
                handler.value()(cancelled);
            }
        });
    };

    auto task = task::make_shared(std::move(task_lambda));

    task_queue queue{1};
    queue.suspend();
    queue.push_back(task);
    queue.resume();

    this->_render_context->queue = std::move(queue);

    return true;
}

void audio::offline_io_core::stop() {
    if (auto &queue = this->_render_context->queue) {
        queue.value().cancel_all();
        queue.value().wait_until_all_tasks_are_finished();
        this->_render_context->queue = std::nullopt;
    }

    if (auto const &handler = this->_device->completion_handler()) {
        handler.value()(true);
    }
}

std::optional<audio::io_kernel_ptr> audio::offline_io_core::_make_kernel() {
    auto const &output_format = this->_device->output_format();

    if (!output_format.has_value()) {
        return std::nullopt;
    }

    if (!this->_render_handler) {
        return std::nullopt;
    }

    return io_kernel::make_shared(this->_render_handler.value(), std::nullopt, output_format, this->_maximum_frames);
}

audio::offline_io_core_ptr audio::offline_io_core::make_shared(offline_device_ptr const &device) {
    return offline_io_core_ptr{new offline_io_core{device}};
}
