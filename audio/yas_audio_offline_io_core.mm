//
//  yas_audio_offline_io_core.cpp
//

#include "yas_audio_offline_io_core.h"
#include <future>
#include "yas_audio_offline_device.h"

using namespace yas;
using namespace yas::audio;

struct offline_io_core::render_context {
    std::optional<std::promise<void>> promise = std::promise<void>();
    std::atomic<bool> is_cancelled = false;

    render_context(std::optional<offline_completion_f> completion) : _completion(std::move(completion)) {
    }

    void stop() {
        raise_if_sub_thread();

        if (this->promise.has_value()) {
            this->is_cancelled = true;

            this->promise.value().get_future().get();

            this->promise = std::nullopt;

            if (auto const &completion = this->_completion) {
                completion.value()(this->is_cancelled);
                this->_completion = std::nullopt;
            }
        }
    }

    void complete() {
        raise_if_sub_thread();

        this->promise = std::nullopt;

        if (auto const &completion = this->_completion) {
            completion.value()(this->is_cancelled);
            this->_completion = std::nullopt;
        }
    }

   private:
    std::optional<offline_completion_f> _completion;
};

offline_io_core::offline_io_core(offline_device_ptr const &device) : _device(device) {
}

offline_io_core::~offline_io_core() {
    this->stop();
}

void offline_io_core::set_render_handler(std::optional<io_render_f> handler) {
    this->_render_handler = std::move(handler);
}

void offline_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    this->_maximum_frames = frames;
}

bool offline_io_core::start() {
    if (this->_render_context) {
        return false;
    }

    auto kernel = this->_make_kernel();

    if (!kernel) {
        return false;
    }

    this->_render_context = std::make_shared<render_context>(this->_device->completion_handler());

    std::thread thread{[kernel = std::move(kernel), render_context = this->_render_context,
                        device_render_handler = this->_device->render_handler()]() mutable {
        uint32_t current_sample_time = 0;

        while (!render_context->is_cancelled) {
            kernel->reset_buffers();

            auto const &render_buffer = kernel->output_buffer;
            if (!render_buffer) {
                render_context->is_cancelled = true;
                break;
            }

            time time(current_sample_time, render_buffer->format().sample_rate());

            kernel->render_handler({.output_buffer = render_buffer.get(),
                                    .output_time = time,
                                    .input_buffer = nullptr,
                                    .input_time = null_time_opt});

            if (device_render_handler({.output_buffer = render_buffer, .output_time = time}) == continuation::abort) {
                break;
            }

            if (render_context->is_cancelled) {
                break;
            }

            current_sample_time += render_buffer->frame_capacity();
        }

        render_context->promise->set_value();

        dispatch_async(dispatch_get_main_queue(), [render_context]() { render_context->complete(); });
    }};

    thread.detach();

    return true;
}

void offline_io_core::stop() {
    if (this->_render_context) {
        this->_render_context->stop();
    }
}

io_kernel_ptr offline_io_core::_make_kernel() const {
    auto const &output_format = this->_device->output_format();

    if (!output_format.has_value()) {
        return nullptr;
    }

    if (!this->_render_handler) {
        return nullptr;
    }

    return io_kernel::make_shared(this->_render_handler.value(), std::nullopt, output_format, this->_maximum_frames);
}

offline_io_core_ptr offline_io_core::make_shared(offline_device_ptr const &device) {
    return offline_io_core_ptr{new offline_io_core{device}};
}
