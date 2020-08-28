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
}

void audio::mac_io_core::uninitialize() {
    this->stop();
    this->_destroy_io_proc();
}

void audio::mac_io_core::set_render_handler(std::optional<io_render_f> handler) {
    if (this->_render_handler || handler) {
        this->_render_handler = std::move(handler);
        this->_reload_io_proc_if_started();
    }
}

void audio::mac_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    if (this->_maximum_frames != frames) {
        this->_maximum_frames = frames;
        this->_reload_io_proc_if_started();
    }
}

bool audio::mac_io_core::start() {
    this->_is_started = true;
    this->_create_io_proc();

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
    this->_destroy_io_proc();
    this->_is_started = false;
}

audio::pcm_buffer const *audio::mac_io_core::input_buffer_on_render() const {
    if (this->_kernel && this->_kernel->input_buffer.has_value()) {
        return this->_kernel->input_buffer.value().get();
    } else {
        return nullptr;
    }
}

void audio::mac_io_core::_create_io_proc() {
    if (this->_io_proc_id) {
        return;
    }

    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!output_format && !input_format) {
        return;
    }

    if (!this->_render_handler) {
        return;
    }

    if (this->_maximum_frames == 0) {
        return;
    }

    this->_kernel =
        io_kernel::make_shared(this->_render_handler.value(), input_format, output_format, this->_maximum_frames);

    auto handler = [kernel = this->_kernel, this](const AudioTimeStamp *inNow, const AudioBufferList *inInputData,
                                                  const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData,
                                                  const AudioTimeStamp *inOutputTime) {
        if (outOutputData) {
            audio::clear(outOutputData);
        }

        kernel->reset_buffers();

        std::optional<time> input_time = std::nullopt;

        if (inInputData) {
            if (auto const &input_buffer_opt = kernel->input_buffer) {
                auto const &input_buffer = input_buffer_opt.value();
                input_buffer->copy_from(inInputData);

                uint32_t const input_frame_length = input_buffer->frame_length();
                if (input_frame_length > 0) {
                    input_time = audio::time{*inInputTime, input_buffer->format().sample_rate()};
                    this->_input_time = &input_time.value();
                }
            }
        }

        if (auto const &output_buffer_opt = kernel->output_buffer) {
            auto const &output_buffer = output_buffer_opt.value();
            if (outOutputData) {
                uint32_t const frame_length =
                    audio::frame_length(outOutputData, output_buffer->format().sample_byte_count());
                if (frame_length > 0) {
                    output_buffer->set_frame_length(frame_length);
                    audio::time time{*inOutputTime, output_buffer->format().sample_rate()};
                    kernel->render_handler(
                        {.output_buffer = output_buffer_opt,
                         .output_time = std::move(time),
                         .input_buffer = input_time.has_value() ? kernel->input_buffer : audio::null_pcm_buffer_ptr_opt,
                         .input_time = input_time});
                    output_buffer->copy_to(outOutputData);
                }
            }
        } else if (input_time.has_value()) {
            kernel->render_handler({.output_buffer = audio::null_pcm_buffer_ptr_opt,
                                    .output_time = audio::null_time_opt,
                                    .input_buffer = kernel->input_buffer,
                                    .input_time = input_time});
        }

        this->_input_time = nullptr;
    };

    AudioDeviceIOProcID io_proc_id = nullptr;
    raise_if_raw_audio_error(
        AudioDeviceCreateIOProcIDWithBlock(&io_proc_id, this->_device->audio_device_id(), nullptr, handler));
    this->_io_proc_id = io_proc_id;
}

void audio::mac_io_core::_destroy_io_proc() {
    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(
            AudioDeviceDestroyIOProcID(this->_device->audio_device_id(), this->_io_proc_id.value()));
    }

    this->_io_proc_id = std::nullopt;
    this->_kernel = nullptr;
}

void audio::mac_io_core::_reload_io_proc_if_started() {
    if (this->_is_started) {
        this->stop();
        this->_destroy_io_proc();
        this->_create_io_proc();
        this->start();
    }
}

audio::mac_io_core_ptr audio::mac_io_core::make_shared(mac_device_ptr const &device) {
    return std::shared_ptr<mac_io_core>(new mac_io_core{device});
}

#endif
