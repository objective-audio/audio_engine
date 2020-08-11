//
//  yas_audio_mac_io_core.cpp
//

#include "yas_audio_mac_io_core.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_mac_device.h"

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
                if (auto const kernel_opt = io_core->_kernel()) {
                    auto const &kernel = kernel_opt.value();
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

                    if (auto const &output_buffer_opt = kernel->output_buffer) {
                        auto const &output_buffer = *output_buffer_opt;
                        if (outOutputData) {
                            uint32_t const frame_length =
                                audio::frame_length(outOutputData, output_buffer->format().sample_byte_count());
                            if (frame_length > 0) {
                                output_buffer->set_frame_length(frame_length);
                                audio::time time(*inOutputTime, output_buffer->format().sample_rate());
                                kernel->render_handler(
                                    io_render_args{.output_buffer = output_buffer_opt, .when = std::move(time)});
                                output_buffer->copy_to(outOutputData);
                            }
                        }
                    } else if (kernel->input_buffer) {
                        kernel->render_handler(io_render_args{.output_buffer = std::nullopt, .when = std::nullopt});
                    }
                }

                io_core->_input_buffer_on_render = std::nullopt;
                io_core->_input_time_on_render = std::nullopt;
            }
        };

        AudioDeviceIOProcID io_proc_id = nullptr;
        raise_if_raw_audio_error(
            AudioDeviceCreateIOProcIDWithBlock(&io_proc_id, this->_device->audio_device_id(), nullptr, handler));
        this->_io_proc_id = io_proc_id;
    }

    this->_update_kernel();
}

void audio::mac_io_core::uninitialize() {
    this->stop();

    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(
            AudioDeviceDestroyIOProcID(this->_device->audio_device_id(), this->_io_proc_id.value()));
    }

    this->_io_proc_id = std::nullopt;
    this->_update_kernel();
}

void audio::mac_io_core::set_render_handler(std::optional<io_render_f> handler) {
    if (this->__render_handler || handler) {
        std::lock_guard<std::recursive_mutex> lock(this->_kernel_mutex);
        this->__render_handler = std::move(handler);
        this->_update_kernel();
    }
}

void audio::mac_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    if (this->__maximum_frames != frames) {
        std::lock_guard<std::recursive_mutex> lock(this->_kernel_mutex);
        this->__maximum_frames = frames;
        this->_update_kernel();
    }
}

bool audio::mac_io_core::start() {
    if (this->_io_proc_id) {
        raise_if_raw_audio_error(AudioDeviceStart(this->_device->audio_device_id(), this->_io_proc_id.value()));
        return true;
    } else {
        return false;
    }
}

void audio::mac_io_core::stop() {
    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(AudioDeviceStop(this->_device->audio_device_id(), this->_io_proc_id.value()));
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
}

void audio::mac_io_core::_set_kernel(std::optional<io_kernel_ptr> const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_kernel_mutex);
    this->__kernel = kernel;
}

std::optional<audio::io_kernel_ptr> audio::mac_io_core::_kernel() const {
    if (auto const lock = std::unique_lock(this->_kernel_mutex, std::try_to_lock); lock.owns_lock()) {
        return this->__kernel;
    } else {
        return std::nullopt;
    }
}

void audio::mac_io_core::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_kernel_mutex);

    this->_set_kernel(std::nullopt);

    if (!this->_is_initialized()) {
        return;
    }

    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!output_format && !input_format) {
        return;
    }

    if (!this->__render_handler) {
        return;
    }

    this->_set_kernel(
        io_kernel::make_shared(this->__render_handler.value(), input_format, output_format, this->__maximum_frames));
}

bool audio::mac_io_core::_is_initialized() const {
    return this->_io_proc_id.has_value();
}

audio::mac_io_core_ptr audio::mac_io_core::make_shared(mac_device_ptr const &device) {
    auto shared = std::shared_ptr<mac_io_core>(new mac_io_core{device});
    shared->_prepare(shared);
    return shared;
}

#endif
