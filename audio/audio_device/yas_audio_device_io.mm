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
#include "yas_audio_pcm_buffer.h"

using namespace yas;

struct audio::device_io::kernel {
    kernel(std::optional<audio::format> const &input_format, std::optional<audio::format> const &output_format,
           uint32_t const frame_capacity)
        : _input_buffer(input_format ? std::make_shared<pcm_buffer>(*input_format, frame_capacity) : nullptr),
          _output_buffer(output_format ? std::make_shared<pcm_buffer>(*output_format, frame_capacity) : nullptr) {
    }

    pcm_buffer_ptr const &input_buffer() {
        return this->_input_buffer;
    }

    pcm_buffer_ptr const &output_buffer() {
        return this->_output_buffer;
    }

    void reset_buffers() {
        if (this->_input_buffer) {
            this->_input_buffer->reset();
        }

        if (this->_output_buffer) {
            this->_output_buffer->reset();
        }
    }

   private:
    pcm_buffer_ptr _input_buffer;
    pcm_buffer_ptr _output_buffer;

    kernel(kernel const &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(kernel const &) = delete;
    kernel &operator=(kernel &&) = delete;
};

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

    if (!this->_device->input_format() && !this->_device->output_format()) {
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
                    if (auto &input_buffer = kernel->input_buffer()) {
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
                    if (auto &output_buffer = kernel->output_buffer()) {
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
        AudioDeviceCreateIOProcIDWithBlock(&this->_io_proc_id, this->_device->audio_device_id(), nullptr, handler));

    this->_update_kernel();
}

void audio::device_io::_uninitialize() {
    this->stop();

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    if (device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(AudioDeviceDestroyIOProcID(this->_device->audio_device_id(), this->_io_proc_id));
    }

    this->_io_proc_id = nullptr;
    this->_update_kernel();
}

void audio::device_io::set_device(audio::device_ptr const device) {
    if (this->_device != device) {
        bool running = this->_is_running;

        this->_uninitialize();

        if (this->_device) {
            if (this->_device_observers.count((uintptr_t)this->_device.get())) {
                this->_device_observers.erase((uintptr_t)this->_device.get());
            }
        }

        this->_device = device;

        if (this->_device) {
            auto observer = this->_device->chain(device::method::device_did_change)
                                .perform([weak_device_io = _weak_device_io](auto const &) {
                                    if (auto device_io = weak_device_io.lock()) {
                                        device_io->_update_kernel();
                                    }
                                })
                                .end();
            this->_device_observers.emplace((uintptr_t)this->_device.get(), std::move(observer));
        }

        this->_initialize();

        if (running) {
            this->start();
        }
    }
}

audio::device_ptr const &audio::device_io::device() const {
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

    raise_if_raw_audio_error(AudioDeviceStart(this->_device->audio_device_id(), this->_io_proc_id));
}

void audio::device_io::stop() {
    if (!this->_is_running) {
        return;
    }

    this->_is_running = false;

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    if (device::is_available_device(this->_device)) {
        raise_if_raw_audio_error(AudioDeviceStop(this->_device->audio_device_id(), this->_io_proc_id));
    }
}

audio::pcm_buffer_ptr const &audio::device_io::input_buffer_on_render() const {
    return this->_input_buffer_on_render;
}

audio::time_ptr const &audio::device_io::input_time_on_render() const {
    return this->_input_time_on_render;
}

void audio::device_io::_prepare(device_io_ptr const &shared, device_ptr const &device) {
    this->_weak_device_io = to_weak(shared);

    this->_device_system_observer =
        device::system_chain(device::system_method::hardware_did_change)
            .perform([weak_device_io = this->_weak_device_io](auto const &) {
                if (auto device_io = weak_device_io.lock()) {
                    if (device_io->device() && !device::device_for_id(device_io->device()->audio_device_id())) {
                        device_io->set_device(nullptr);
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

void audio::device_io::_set_kernel(device_io::kernel_ptr const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = nullptr;
    if (kernel) {
        this->__kernel = kernel;
    }
}

audio::device_io::kernel_ptr audio::device_io::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::device_io::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(nullptr);

    if (!this->_device || !this->_io_proc_id) {
        return;
    }

    this->_set_kernel(std::make_shared<device_io::kernel>(this->_device->input_format(), this->_device->output_format(),
                                                          this->__maximum_frames));
}

audio::device_io_ptr audio::device_io::make_shared(device_ptr const &device) {
    auto shared = device_io_ptr(new audio::device_io{});
    shared->_prepare(shared, device);
    return shared;
}

#endif
