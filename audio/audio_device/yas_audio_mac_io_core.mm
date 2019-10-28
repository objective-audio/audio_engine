//
//  yas_audio_mac_io_core.cpp
//

#include "yas_audio_mac_io_core.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

using namespace yas;

audio::mac_io_core::mac_io_core(mac_device_ptr const &device) : _device(device) {
}

audio::mac_io_core::~mac_io_core() {
    this->uninitialize();
}

void audio::mac_io_core::initialize() {
    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!input_format && !output_format) {
        this->_update_kernel();
        return;
    }

    if (!this->_io_proc_id) {
        auto handler = [weak_io_core = this->_weak_io_core](
                           const AudioTimeStamp *inNow, const AudioBufferList *inInputData,
                           const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData,
                           const AudioTimeStamp *inOutputTime) {
            if (outOutputData) {
                audio::clear(outOutputData);
            }

            if (auto io_core = weak_io_core.lock()) {
                if (auto kernel = io_core->_kernel()) {
                    kernel->reset_buffers();
                    if (inInputData) {
                        if (auto const &input_buffer_opt = kernel->input_buffer) {
                            auto const &input_buffer = *input_buffer_opt;
                            input_buffer->copy_from(inInputData);

                            uint32_t const input_frame_length = input_buffer->frame_length();
                            if (input_frame_length > 0) {
                                io_core->_input_buffer_on_render = input_buffer;
                                io_core->_input_time_on_render =
                                    std::make_shared<audio::time>(*inInputTime, input_buffer->format().sample_rate());
                            }
                        }
                    }

                    if (auto render_handler = io_core->_render_handler()) {
                        if (auto const &output_buffer_opt = kernel->output_buffer) {
                            auto const &output_buffer = *output_buffer_opt;
                            if (outOutputData) {
                                uint32_t const frame_length =
                                    audio::frame_length(outOutputData, output_buffer->format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer->set_frame_length(frame_length);
                                    audio::time time(*inOutputTime, output_buffer->format().sample_rate());
                                    render_handler(
                                        io_render_args{.output_buffer = output_buffer_opt, .when = std::move(time)});
                                    output_buffer->copy_to(outOutputData);
                                }
                            }
                        } else if (kernel->input_buffer) {
                            render_handler(io_render_args{.output_buffer = std::nullopt, .when = std::nullopt});
                        }
                    }
                }

                io_core->_input_buffer_on_render = std::nullopt;
                io_core->_input_time_on_render = std::nullopt;
            }
        };

        raise_if_raw_audio_error(
            AudioDeviceCreateIOProcIDWithBlock(&this->_io_proc_id, this->_device->audio_device_id(), nullptr, handler));
    }

    this->_update_kernel();
}

void audio::mac_io_core::uninitialize() {
    this->stop();

    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(AudioDeviceDestroyIOProcID(this->_device->audio_device_id(), this->_io_proc_id));
    }

    this->_io_proc_id = nullptr;
    this->_update_kernel();
}

void audio::mac_io_core::set_render_handler(io_render_f handler) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__render_handler = std::move(handler);
}

void audio::mac_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__maximum_frames = frames;
    this->_update_kernel();
}

bool audio::mac_io_core::start() {
    if (this->_io_proc_id) {
        raise_if_raw_audio_error(AudioDeviceStart(this->_device->audio_device_id(), this->_io_proc_id));
        return true;
    } else {
        return false;
    }
}

void audio::mac_io_core::stop() {
    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(AudioDeviceStop(this->_device->audio_device_id(), this->_io_proc_id));
    }
}

std::optional<audio::pcm_buffer_ptr> const &audio::mac_io_core::input_buffer_on_render() const {
    return this->_input_buffer_on_render;
}

std::optional<audio::time_ptr> const &audio::mac_io_core::input_time_on_render() const {
    return this->_input_time_on_render;
}

void audio::mac_io_core::_prepare(mac_io_core_ptr const &shared) {
    auto weak_io_core = to_weak(shared);
    this->_weak_io_core = weak_io_core;

    this->_device_observer = this->_device->chain(mac_device::method::device_did_change)
                                 .perform([weak_io_core](auto const &) {
                                     if (auto io_core = weak_io_core.lock()) {
                                         io_core->_notifier->notify(method::updated);
                                     }
                                 })
                                 .end();

    this->_device_system_observer =
        mac_device::system_chain(mac_device::system_method::hardware_did_change)
            .perform([weak_io_core, audio_device_id = this->_device->audio_device_id()](auto const &) {
                if (auto io_core = weak_io_core.lock()) {
                    if (!mac_device::device_for_id(audio_device_id)) {
                        io_core->_notifier->notify(method::lost);
                    }
                }
            })
            .end();
}

audio::io_render_f audio::mac_io_core::_render_handler() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__render_handler;
}

void audio::mac_io_core::_set_kernel(io_kernel_ptr const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = nullptr;
    if (kernel) {
        this->__kernel = kernel;
    }
}

audio::io_kernel_ptr audio::mac_io_core::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::mac_io_core::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(nullptr);

    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!output_format && !input_format) {
        return;
    }

    this->_set_kernel(io_kernel::make_shared(input_format, output_format, this->__maximum_frames));
}

audio::mac_io_core_ptr audio::mac_io_core::make_shared(mac_device_ptr const &device) {
    auto shared = std::shared_ptr<mac_io_core>(new mac_io_core{device});
    shared->_prepare(shared);
    return shared;
}

#endif
