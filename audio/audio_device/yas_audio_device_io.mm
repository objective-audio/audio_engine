//
//  yas_audio_device_io.mm
//

#include "yas_audio_device_io.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <cpp_utils/yas_exception.h>
#include <cpp_utils/yas_result.h>
#include <mutex>
#include "yas_audio_device.h"
#include "yas_audio_format.h"
#include "yas_audio_io_kernel.h"
#include "yas_audio_pcm_buffer.h"

using namespace yas;

#pragma mark -

audio::device_io::device_io() = default;

audio::device_io::~device_io() {
    this->_device_system_observer = nullptr;

    this->_uninitialize();
}

void audio::device_io::_initialize() {
    if (!this->_device || this->_io_proc_id) {
        return;
    }

    auto const &device = *this->_device;

    if (!device->input_format() && !device->output_format()) {
        return;
    }

    auto handler = [weak_device_io = _weak_device_io](const AudioTimeStamp *inNow, const AudioBufferList *inInputData,
                                                      const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData,
                                                      const AudioTimeStamp *inOutputTime) {
        if (outOutputData) {
            audio::clear(outOutputData);
        }

        if (auto device_io = weak_device_io.lock()) {
            if (auto kernel = device_io->_kernel()) {
                kernel->reset_buffers();
                if (inInputData) {
                    if (auto const &input_buffer_opt = kernel->input_buffer()) {
                        auto const &input_buffer = *input_buffer_opt;
                        input_buffer->copy_from(inInputData);

                        uint32_t const input_frame_length = input_buffer->frame_length();
                        if (input_frame_length > 0) {
                            device_io->_input_buffer_on_render = input_buffer;
                            device_io->_input_time_on_render =
                                std::make_shared<audio::time>(*inInputTime, input_buffer->format().sample_rate());
                        }
                    }
                }

                if (auto render_handler = device_io->_render_handler()) {
                    if (auto const &output_buffer_opt = kernel->output_buffer()) {
                        auto const &output_buffer = *output_buffer_opt;
                        if (outOutputData) {
                            uint32_t const frame_length =
                                audio::frame_length(outOutputData, output_buffer->format().sample_byte_count());
                            if (frame_length > 0) {
                                output_buffer->set_frame_length(frame_length);
                                audio::time time(*inOutputTime, output_buffer->format().sample_rate());
                                render_handler(render_args{.output_buffer = output_buffer, .when = std::move(time)});
                                output_buffer->copy_to(outOutputData);
                            }
                        }
                    } else if (kernel->input_buffer()) {
                        pcm_buffer_ptr null_buffer{nullptr};
                        render_handler(render_args{.output_buffer = null_buffer, .when = std::nullopt});
                    }
                }
            }

            device_io->_input_buffer_on_render = nullptr;
            device_io->_input_time_on_render = nullptr;
        }
    };

    raise_if_raw_audio_error(
        AudioDeviceCreateIOProcIDWithBlock(&this->_io_proc_id, device->audio_device_id(), nullptr, handler));

    this->_update_kernel();
}

void audio::device_io::_uninitialize() {
    this->stop();

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    auto const &device = *this->_device;

    if (device::is_available_device(device)) {
        raise_if_raw_audio_error(AudioDeviceDestroyIOProcID(device->audio_device_id(), this->_io_proc_id));
    }

    this->_io_proc_id = nullptr;
    this->_update_kernel();
}

void audio::device_io::set_device(std::optional<audio::device_ptr> const device) {
    if (this->_device != device) {
        bool running = this->_is_running;

        this->_uninitialize();

        if (this->_device) {
            auto const &device = *this->_device;
            if (this->_device_observers.count((uintptr_t)device.get())) {
                this->_device_observers.erase((uintptr_t)device.get());
            }
        }

        this->_device = device;

        if (this->_device) {
            auto const &device = *this->_device;
            auto observer = device->chain(device::method::device_did_change)
                                .perform([weak_device_io = _weak_device_io](auto const &) {
                                    if (auto device_io = weak_device_io.lock()) {
                                        device_io->_update_kernel();
                                    }
                                })
                                .end();
            this->_device_observers.emplace((uintptr_t)device.get(), std::move(observer));
        }

        this->_initialize();

        if (running) {
            this->start();
        }
    }
}

std::optional<audio::device_ptr> const &audio::device_io::device() const {
    return this->_device;
}

bool audio::device_io::is_running() const {
    return this->_is_running;
}

void audio::device_io::set_render_handler(render_f handler) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__render_handler = std::move(handler);
}

void audio::device_io::set_maximum_frames_per_slice(uint32_t const frames) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__maximum_frames = frames;
    this->_update_kernel();
}

uint32_t audio::device_io::maximum_frames_per_slice() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__maximum_frames;
}

void audio::device_io::start() {
    this->_is_running = true;

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    auto const &device = *this->_device;

    raise_if_raw_audio_error(AudioDeviceStart(device->audio_device_id(), this->_io_proc_id));
}

void audio::device_io::stop() {
    if (!this->_is_running) {
        return;
    }

    this->_is_running = false;

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    auto const &device = *this->_device;

    if (device::is_available_device(device)) {
        raise_if_raw_audio_error(AudioDeviceStop(device->audio_device_id(), this->_io_proc_id));
    }
}

audio::pcm_buffer_ptr const &audio::device_io::input_buffer_on_render() const {
    return this->_input_buffer_on_render;
}

audio::time_ptr const &audio::device_io::input_time_on_render() const {
    return this->_input_time_on_render;
}

void audio::device_io::_prepare(device_io_ptr const &shared, std::optional<device_ptr> const &device) {
    this->_weak_device_io = to_weak(shared);

    this->_device_system_observer = device::system_chain(device::system_method::hardware_did_change)
                                        .perform([weak_device_io = this->_weak_device_io](auto const &) {
                                            if (auto device_io = weak_device_io.lock()) {
                                                if (auto const &device_opt = device_io->device()) {
                                                    auto const &device = *device_opt;
                                                    if (!device::device_for_id(device->audio_device_id())) {
                                                        device_io->set_device(std::nullopt);
                                                    }
                                                }
                                            }
                                        })
                                        .end();

    this->set_device(device);
}

audio::device_io::render_f audio::device_io::_render_handler() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__render_handler;
}

void audio::device_io::_set_kernel(io_kernel_ptr const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = nullptr;
    if (kernel) {
        this->__kernel = kernel;
    }
}

audio::io_kernel_ptr audio::device_io::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::device_io::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(nullptr);

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    auto const &device = *this->_device;

    this->_set_kernel(
        std::make_shared<io_kernel>(device->input_format(), device->output_format(), this->__maximum_frames));
}

audio::device_io_ptr audio::device_io::make_shared(std::optional<device_ptr> const &device) {
    auto shared = device_io_ptr(new audio::device_io{});
    shared->_prepare(shared, device);
    return shared;
}

#endif
