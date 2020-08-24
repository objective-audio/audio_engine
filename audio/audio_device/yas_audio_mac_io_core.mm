//
//  yas_audio_mac_io_core.cpp
//

#include "yas_audio_mac_io_core.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_mac_device.h"

using namespace yas;

namespace yas::audio {
struct mac_io_core_render_context {
    std::optional<io_kernel_ptr> const kernel;
    std::optional<pcm_buffer_ptr> input_buffer_on_render = std::nullopt;
    std::optional<time_ptr> input_time_on_render = std::nullopt;

    static std::shared_ptr<mac_io_core_render_context> make_shared(io_kernel_ptr const &kernel) {
        return std::shared_ptr<mac_io_core_render_context>(new mac_io_core_render_context{kernel});
    }

   private:
    mac_io_core_render_context(io_kernel_ptr const &kernel) : kernel(kernel) {
    }
};
}

audio::mac_io_core::mac_io_core(mac_device_ptr const &device) : _device(device) {
}

audio::mac_io_core::~mac_io_core() {
    this->uninitialize();
}

void audio::mac_io_core::initialize() {
    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!input_format && !output_format) {
        return;
    }

    if (this->_maximum_frames == 0) {
        return;
    }

    if (!this->_render_handler) {
        return;
    }

    if (!this->_io_proc_id) {
        auto const kernel =
            io_kernel::make_shared(this->_render_handler.value(), input_format, output_format, this->_maximum_frames);
        auto const render_context = mac_io_core_render_context::make_shared(kernel);
        this->_render_context = render_context;

        auto handler = [render_context](const AudioTimeStamp *inNow, const AudioBufferList *inInputData,
                                        const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData,
                                        const AudioTimeStamp *inOutputTime) {
            if (outOutputData) {
                audio::clear(outOutputData);
            }

            if (auto const kernel_opt = render_context->kernel) {
                auto const &kernel = kernel_opt.value();
                kernel->reset_buffers();

                std::optional<audio::pcm_buffer_ptr> render_input_buffer{std::nullopt};
                std::optional<audio::time> render_input_time{std::nullopt};

                if (inInputData) {
                    if (auto const &input_buffer_opt = kernel->input_buffer) {
                        auto const &input_buffer = input_buffer_opt.value();
                        input_buffer->copy_from(inInputData);

                        uint32_t const input_frame_length = input_buffer->frame_length();
                        if (input_frame_length > 0) {
                            auto const input_time =
                                std::make_shared<audio::time>(*inInputTime, input_buffer->format().sample_rate());
                            render_input_buffer = input_buffer;
                            render_input_time = *input_time;
                            render_context->input_buffer_on_render = input_buffer;
                            render_context->input_time_on_render = input_time;
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
                            audio::time time(*inOutputTime, output_buffer->format().sample_rate());
                            kernel->render_handler({.output_buffer = output_buffer_opt,
                                                    .output_time = std::move(time),
                                                    .input_buffer = render_input_buffer,
                                                    .input_time = render_input_time});
                            output_buffer->copy_to(outOutputData);
                        }
                    }
                } else if (kernel->input_buffer) {
                    kernel->render_handler({.output_buffer = audio::null_pcm_buffer_ptr_opt,
                                            .output_time = audio::null_time_opt,
                                            .input_buffer = render_input_buffer,
                                            .input_time = render_input_time});
                }
            }

            render_context->input_buffer_on_render = audio::null_pcm_buffer_ptr_opt;
            render_context->input_time_on_render = audio::null_time_ptr_opt;
        };

        AudioDeviceIOProcID io_proc_id = nullptr;
        raise_if_raw_audio_error(AudioDeviceCreateIOProcIDWithBlock(&io_proc_id, this->_device->audio_device_id(),
                                                                    nullptr, std::move(handler)));
        this->_io_proc_id = io_proc_id;
    }
}

void audio::mac_io_core::uninitialize() {
    this->stop();

    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(
            AudioDeviceDestroyIOProcID(this->_device->audio_device_id(), this->_io_proc_id.value()));
    }

    this->_io_proc_id = std::nullopt;
    this->_render_context = std::nullopt;
}

void audio::mac_io_core::set_render_handler(std::optional<io_render_f> handler) {
    if (this->_render_handler || handler) {
        this->_render_handler = std::move(handler);
        this->_reinitialize();
    }
}

void audio::mac_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    if (this->_maximum_frames != frames) {
        this->_maximum_frames = frames;
        this->_reinitialize();
    }
}

bool audio::mac_io_core::start() {
    if (this->_io_proc_id) {
        raise_if_raw_audio_error(AudioDeviceStart(this->_device->audio_device_id(), this->_io_proc_id.value()));
        this->_is_started = true;
        return true;
    } else {
        return false;
    }
}

void audio::mac_io_core::stop() {
    if (this->_io_proc_id && mac_device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(AudioDeviceStop(this->_device->audio_device_id(), this->_io_proc_id.value()));
    }
    this->_is_started = false;
}

std::optional<audio::pcm_buffer_ptr> const &audio::mac_io_core::input_buffer_on_render() const {
    if (this->_render_context) {
        return this->_render_context.value()->input_buffer_on_render;
    } else {
        return audio::null_pcm_buffer_ptr_opt;
    }
}

std::optional<audio::time_ptr> const &audio::mac_io_core::input_time_on_render() const {
    if (this->_render_context) {
        return this->_render_context.value()->input_time_on_render;
    } else {
        return audio::null_time_ptr_opt;
    }
}

bool audio::mac_io_core::_is_initialized() const {
    return this->_io_proc_id.has_value();
}

void audio::mac_io_core::_reinitialize() {
    if (this->_is_initialized()) {
        auto const is_started = this->_is_started;

        this->uninitialize();
        this->initialize();

        if (is_started) {
            this->start();
        }
    }
}

audio::mac_io_core_ptr audio::mac_io_core::make_shared(mac_device_ptr const &device) {
    return std::shared_ptr<mac_io_core>(new mac_io_core{device});
}

#endif
