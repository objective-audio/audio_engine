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
    struct impl {
        std::shared_ptr<pcm_buffer> _input_buffer;
        std::shared_ptr<pcm_buffer> _output_buffer;

        impl(std::optional<audio::format> const &input_format, std::optional<audio::format> const &output_format,
             uint32_t const frame_capacity)
            : _input_buffer(input_format ? std::make_shared<pcm_buffer>(*input_format, frame_capacity) : nullptr),
              _output_buffer(output_format ? std::make_shared<pcm_buffer>(*output_format, frame_capacity) : nullptr) {
        }

        void reset_buffers() {
            if (this->_input_buffer) {
                this->_input_buffer->reset();
            }

            if (this->_output_buffer) {
                this->_output_buffer->reset();
            }
        }
    };

    kernel(std::optional<audio::format> const &input_format, std::optional<audio::format> const &output_format,
           uint32_t const frame_capacity)
        : _impl(std::make_shared<impl>(input_format, output_format, frame_capacity)) {
    }

    std::shared_ptr<pcm_buffer> &input_buffer() {
        return this->_impl->_input_buffer;
    }

    std::shared_ptr<pcm_buffer> &output_buffer() {
        return this->_impl->_output_buffer;
    }

    void reset_buffers() {
        this->_impl->reset_buffers();
    }
    
private:
    std::shared_ptr<impl> _impl;
};

struct audio::device_io::impl : weakable_impl {
    std::optional<weak_ref<device_io>> _weak_device_io = std::nullopt;
    std::shared_ptr<audio::device> _device = nullptr;
    bool _is_running = false;
    AudioDeviceIOProcID _io_proc_id = nullptr;
    std::shared_ptr<pcm_buffer> _input_buffer_on_render = nullptr;
    std::shared_ptr<audio::time> _input_time_on_render = nullptr;
    chaining::any_observer_ptr _device_system_observer = nullptr;
    std::unordered_map<std::uintptr_t, chaining::any_observer_ptr> _device_observers;

    ~impl() {
        this->_device_system_observer = nullptr;

        this->uninitialize();
    }

    void prepare(audio::device_io const &device_io, std::shared_ptr<audio::device> const device) {
        this->_weak_device_io = std::make_optional<weak_ref<audio::device_io>>(to_weak(device_io));

        this->_device_system_observer =
            device::system_chain(device::system_method::hardware_did_change)
                .perform([weak_device_io = this->_weak_device_io](auto const &) {
                    if (weak_device_io) {
                        if (auto device_io = weak_device_io->lock()) {
                            if (device_io->device() && !device::device_for_id(device_io->device()->audio_device_id())) {
                                device_io->set_device(nullptr);
                            }
                        }
                    }
                })
                .end();

        this->set_device(device);
    }

    void set_device(std::shared_ptr<audio::device> const &device) {
        if (this->_device != device) {
            bool running = this->_is_running;

            this->uninitialize();

            if (this->_device) {
                if (this->_device_observers.count((uintptr_t)this->_device.get())) {
                    this->_device_observers.erase((uintptr_t)this->_device.get());
                }
            }

            this->_device = device;

            if (this->_device) {
                auto observer = this->_device->chain(device::method::device_did_change)
                                    .perform([weak_device_io = _weak_device_io](auto const &) {
                                        if (weak_device_io) {
                                            if (auto device_io = weak_device_io->lock()) {
                                                device_io->_impl->update_kernel();
                                            }
                                        }
                                    })
                                    .end();
                this->_device_observers.emplace((uintptr_t)this->_device.get(), std::move(observer));
            }

            this->initialize();

            if (running) {
                this->start();
            }
        }
    }

    void initialize() {
        if (!this->_device || this->_io_proc_id) {
            return;
        }

        if (!this->_device->input_format() && !this->_device->output_format()) {
            return;
        }

        auto handler = [weak_device_io = _weak_device_io](
                           const AudioTimeStamp *inNow, const AudioBufferList *inInputData,
                           const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData,
                           const AudioTimeStamp *inOutputTime) {
            if (outOutputData) {
                audio::clear(outOutputData);
            }
            
            if (!weak_device_io) {
                return;
            }

            if (auto device_io = weak_device_io->lock()) {
                auto &imp = device_io->_impl;
                if (auto kernel = imp->kernel()) {
                    kernel->reset_buffers();
                    if (inInputData) {
                        if (auto &input_buffer = kernel->input_buffer()) {
                            input_buffer->copy_from(inInputData);

                            uint32_t const input_frame_length = input_buffer->frame_length();
                            if (input_frame_length > 0) {
                                imp->_input_buffer_on_render = input_buffer;
                                imp->_input_time_on_render =
                                    std::make_shared<audio::time>(*inInputTime, input_buffer->format().sample_rate());
                            }
                        }
                    }

                    if (auto render_handler = imp->render_handler()) {
                        if (auto &output_buffer = kernel->output_buffer()) {
                            if (outOutputData) {
                                uint32_t const frame_length =
                                    audio::frame_length(outOutputData, output_buffer->format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer->set_frame_length(frame_length);
                                    audio::time time(*inOutputTime, output_buffer->format().sample_rate());
                                    render_handler(
                                        render_args{.output_buffer = output_buffer, .when = std::move(time)});
                                    output_buffer->copy_to(outOutputData);
                                }
                            }
                        } else if (kernel->input_buffer()) {
                            std::shared_ptr<pcm_buffer> null_buffer{nullptr};
                            render_handler(render_args{.output_buffer = null_buffer, .when = std::nullopt});
                        }
                    }
                }

                imp->_input_buffer_on_render = nullptr;
                imp->_input_time_on_render = nullptr;
            }
        };

        raise_if_raw_audio_error(
            AudioDeviceCreateIOProcIDWithBlock(&this->_io_proc_id, this->_device->audio_device_id(), nullptr, handler));

        this->update_kernel();
    }

    void uninitialize() {
        this->stop();

        if (!this->_device || !this->_io_proc_id) {
            return;
        }

        if (device::is_available_device(*this->_device)) {
            raise_if_raw_audio_error(AudioDeviceDestroyIOProcID(this->_device->audio_device_id(), this->_io_proc_id));
        }

        this->_io_proc_id = nullptr;
        this->update_kernel();
    }

    void start() {
        this->_is_running = true;

        if (!this->_device || !this->_io_proc_id) {
            return;
        }

        raise_if_raw_audio_error(AudioDeviceStart(this->_device->audio_device_id(), this->_io_proc_id));
    }

    void stop() {
        if (!this->_is_running) {
            return;
        }

        this->_is_running = false;

        if (!this->_device || !this->_io_proc_id) {
            return;
        }

        if (device::is_available_device(*this->_device)) {
            raise_if_raw_audio_error(AudioDeviceStop(this->_device->audio_device_id(), this->_io_proc_id));
        }
    }

    void set_render_handler(render_f &&handler) {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        this->_render_handler = std::move(handler);
    }

    render_f render_handler() const {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        return this->_render_handler;
    }

    void set_maximum_frames(uint32_t const frames) {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        this->_maximum_frames = frames;
        this->update_kernel();
    }

    uint32_t maximum_frames() const {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        return this->_maximum_frames;
    }

    void set_kernel(std::shared_ptr<device_io::kernel> kernel) {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        this->_kernel = nullptr;
        if (kernel) {
            this->_kernel = std::move(kernel);
        }
    }

    std::shared_ptr<device_io::kernel> kernel() const {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);
        return this->_kernel;
    }

    void update_kernel() {
        std::lock_guard<std::recursive_mutex> lock(this->_mutex);

        this->set_kernel(nullptr);

        if (!this->_device || !this->_io_proc_id) {
            return;
        }

        this->set_kernel(std::make_shared<device_io::kernel>(this->_device->input_format(), this->_device->output_format(), this->_maximum_frames));
    }

   private:
    render_f _render_handler = nullptr;
    uint32_t _maximum_frames = 4096;
    std::shared_ptr<device_io::kernel> _kernel = nullptr;
    mutable std::recursive_mutex _mutex;
};

#pragma mark -

audio::device_io::device_io(std::shared_ptr<audio::device> const &device) : _impl(std::make_shared<impl>()) {
    this->_impl->prepare(*this, device);
}

void audio::device_io::_initialize() const {
    this->_impl->initialize();
}

void audio::device_io::_uninitialize() const {
    this->_impl->uninitialize();
}

void audio::device_io::set_device(std::shared_ptr<audio::device> const device) {
    this->_impl->set_device(device);
}

std::shared_ptr<audio::device> const &audio::device_io::device() const {
    return this->_impl->_device;
}

bool audio::device_io::is_running() const {
    return this->_impl->_is_running;
}

void audio::device_io::set_render_handler(render_f callback) {
    this->_impl->set_render_handler(std::move(callback));
}

void audio::device_io::set_maximum_frames_per_slice(uint32_t const frames) {
    this->_impl->set_maximum_frames(frames);
}

uint32_t audio::device_io::maximum_frames_per_slice() const {
    return this->_impl->maximum_frames();
}

void audio::device_io::start() const {
    this->_impl->start();
}

void audio::device_io::stop() const {
    this->_impl->stop();
}

std::shared_ptr<audio::pcm_buffer> &audio::device_io::input_buffer_on_render() {
    return this->_impl->_input_buffer_on_render;
}

std::shared_ptr<audio::time> const &audio::device_io::input_time_on_render() const {
    return this->_impl->_input_time_on_render;
}

std::shared_ptr<weakable_impl> audio::device_io::weakable_impl_ptr() const {
    return this->_impl;
}

#endif
