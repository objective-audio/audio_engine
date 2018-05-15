//
//  yas_audio_device_io.mm
//

#include "yas_audio_device_io.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <mutex>
#include "yas_audio_device.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_time.h"
#include "yas_exception.h"
#include "yas_observing.h"
#include "yas_result.h"

using namespace yas;

struct audio::device_io::kernel : base {
    struct impl : base::impl {
        pcm_buffer _input_buffer;
        pcm_buffer _output_buffer;

        impl(audio::format const &input_format, audio::format const &output_format, uint32_t const frame_capacity)
            : _input_buffer(input_format ? pcm_buffer{input_format, frame_capacity} : nullptr),
              _output_buffer(output_format ? pcm_buffer{output_format, frame_capacity} : nullptr) {
        }

        void reset_buffers() {
            if (_input_buffer) {
                _input_buffer.reset();
            }

            if (_output_buffer) {
                _output_buffer.reset();
            }
        }
    };

    kernel(audio::format const &input_format, audio::format const &output_format, uint32_t const frame_capacity)
        : base(std::make_shared<impl>(input_format, output_format, frame_capacity)) {
    }

    kernel(std::nullptr_t) : base(nullptr) {
    }

    pcm_buffer &input_buffer() {
        return impl_ptr<impl>()->_input_buffer;
    }

    pcm_buffer &output_buffer() {
        return impl_ptr<impl>()->_output_buffer;
    }

    void reset_buffers() {
        impl_ptr<impl>()->reset_buffers();
    }
};

struct audio::device_io::impl : base::impl {
    weak<device_io> _weak_device_io;
    audio::device _device = nullptr;
    bool _is_running = false;
    AudioDeviceIOProcID _io_proc_id = nullptr;
    pcm_buffer _input_buffer_on_render = nullptr;
    audio::time _input_time_on_render = nullptr;
    audio::device::observer_t _observer;

    impl() {
    }

    ~impl() {
        _observer.remove_handler(device::system_subject(), device::method::hardware_did_change);

        uninitialize();
    }

    void prepare(device_io const &device_io, audio::device const dev) {
        _weak_device_io = to_weak(device_io);

        _observer.add_handler(
            device::system_subject(), device::method::hardware_did_change,
            [weak_device_io = _weak_device_io](auto const &context) {
                if (auto device_io = weak_device_io.lock()) {
                    if (device_io.device() && !device::device_for_id(device_io.device().audio_device_id())) {
                        device_io.set_device(nullptr);
                    }
                }
            });

        set_device(dev);
    }

    void set_device(audio::device const &dev) {
        if (_device != dev) {
            bool running = _is_running;

            uninitialize();

            if (_device) {
                _observer.remove_handler(_device.subject(), device::method::device_did_change);
            }

            _device = dev;

            if (_device) {
                _observer.add_handler(_device.subject(), device::method::device_did_change,
                                      [weak_device_io = _weak_device_io](auto const &context) {
                                          if (auto device_io = weak_device_io.lock()) {
                                              device_io.impl_ptr<impl>()->update_kernel();
                                          }
                                      });
            }

            initialize();

            if (running) {
                start();
            }
        }
    }

    void initialize() {
        if (!_device || _io_proc_id) {
            return;
        }

        if (!_device.input_format() && !_device.output_format()) {
            return;
        }

        auto handler = [weak_device_io = _weak_device_io](
                           const AudioTimeStamp *inNow, const AudioBufferList *inInputData,
                           const AudioTimeStamp *inInputTime, AudioBufferList *outOutputData,
                           const AudioTimeStamp *inOutputTime) {
            if (outOutputData) {
                audio::clear(outOutputData);
            }

            if (auto device_io = weak_device_io.lock()) {
                auto imp = device_io.impl_ptr<impl>();
                if (auto kernel = imp->kernel()) {
                    kernel.reset_buffers();
                    if (inInputData) {
                        if (auto &input_buffer = kernel.input_buffer()) {
                            input_buffer.copy_from(inInputData);

                            uint32_t const input_frame_length = input_buffer.frame_length();
                            if (input_frame_length > 0) {
                                imp->_input_buffer_on_render = input_buffer;
                                imp->_input_time_on_render =
                                    audio::time(*inInputTime, input_buffer.format().sample_rate());
                            }
                        }
                    }

                    if (auto render_handler = imp->render_handler()) {
                        if (auto &output_buffer = kernel.output_buffer()) {
                            if (outOutputData) {
                                uint32_t const frame_length =
                                    audio::frame_length(outOutputData, output_buffer.format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer.set_frame_length(frame_length);
                                    audio::time time(*inOutputTime, output_buffer.format().sample_rate());
                                    render_handler({.output_buffer = output_buffer, .when = time});
                                    output_buffer.copy_to(outOutputData);
                                }
                            }
                        } else if (kernel.input_buffer()) {
                            pcm_buffer null_buffer{nullptr};
                            render_handler({.output_buffer = null_buffer, .when = nullptr});
                        }
                    }
                }

                imp->_input_buffer_on_render = nullptr;
                imp->_input_time_on_render = nullptr;
            }
        };

        raise_if_raw_audio_error(
            AudioDeviceCreateIOProcIDWithBlock(&_io_proc_id, _device.audio_device_id(), nullptr, handler));

        update_kernel();
    }

    void uninitialize() {
        stop();

        if (!_device || !_io_proc_id) {
            return;
        }

        if (device::is_available_device(_device)) {
            raise_if_raw_audio_error(AudioDeviceDestroyIOProcID(_device.audio_device_id(), _io_proc_id));
        }

        _io_proc_id = nullptr;
        update_kernel();
    }

    void start() {
        _is_running = true;

        if (!_device || !_io_proc_id) {
            return;
        }

        raise_if_raw_audio_error(AudioDeviceStart(_device.audio_device_id(), _io_proc_id));
    }

    void stop() {
        if (!_is_running) {
            return;
        }

        _is_running = false;

        if (!_device || !_io_proc_id) {
            return;
        }

        if (device::is_available_device(_device)) {
            raise_if_raw_audio_error(AudioDeviceStop(_device.audio_device_id(), _io_proc_id));
        }
    }

    void set_render_handler(render_f &&handler) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_handler = std::move(handler);
    }

    render_f render_handler() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_handler;
    }

    void set_maximum_frames(uint32_t const frames) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _maximum_frames = frames;
        update_kernel();
    }

    uint32_t maximum_frames() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _maximum_frames;
    }

    void set_kernel(device_io::kernel kernel) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = nullptr;
        if (kernel) {
            _kernel = std::move(kernel);
        }
    }

    device_io::kernel kernel() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void update_kernel() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        set_kernel(nullptr);

        if (!_device || !_io_proc_id) {
            return;
        }

        set_kernel(device_io::kernel{_device.input_format(), _device.output_format(), _maximum_frames});
    }

   private:
    render_f _render_handler = nullptr;
    uint32_t _maximum_frames = 4096;
    device_io::kernel _kernel = nullptr;
    mutable std::recursive_mutex _mutex;
};

#pragma mark -

audio::device_io::device_io(std::nullptr_t) : base(nullptr) {
}

audio::device_io::device_io(audio::device const &device) : base(std::make_shared<impl>()) {
    impl_ptr<impl>()->prepare(*this, device);
}

void audio::device_io::_initialize() const {
    impl_ptr<impl>()->initialize();
}

void audio::device_io::_uninitialize() const {
    impl_ptr<impl>()->uninitialize();
}

void audio::device_io::set_device(audio::device const device) {
    impl_ptr<impl>()->set_device(device);
}

audio::device audio::device_io::device() const {
    return impl_ptr<impl>()->_device;
}

bool audio::device_io::is_running() const {
    return impl_ptr<impl>()->_is_running;
}

void audio::device_io::set_render_handler(render_f callback) {
    impl_ptr<impl>()->set_render_handler(std::move(callback));
}

void audio::device_io::set_maximum_frames_per_slice(uint32_t const frames) {
    impl_ptr<impl>()->set_maximum_frames(frames);
}

uint32_t audio::device_io::maximum_frames_per_slice() const {
    return impl_ptr<impl>()->maximum_frames();
}

void audio::device_io::start() const {
    impl_ptr<impl>()->start();
}

void audio::device_io::stop() const {
    impl_ptr<impl>()->stop();
}

audio::pcm_buffer const &audio::device_io::input_buffer_on_render() const {
    return impl_ptr<impl>()->_input_buffer_on_render;
}

audio::time const &audio::device_io::input_time_on_render() const {
    return impl_ptr<impl>()->_input_time_on_render;
}

#endif
