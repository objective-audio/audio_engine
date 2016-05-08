//
//  yas_audio_device_io.mm
//

#include "yas_audio_device_io.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <memory>
#include <mutex>
#include "yas_audio_device.h"
#include "yas_audio_format.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_time.h"
#include "yas_exception.h"
#include "yas_observing.h"

using namespace yas;

struct audio::device_io::kernel {
    pcm_buffer input_buffer;
    pcm_buffer output_buffer;

    kernel(audio::format const &input_format, audio::format const &output_format, UInt32 const frame_capacity)
        : input_buffer(input_format ? pcm_buffer(input_format, frame_capacity) : nullptr),
          output_buffer(output_format ? pcm_buffer(output_format, frame_capacity) : nullptr) {
    }

    void reset_buffers() {
        input_buffer.reset();
        output_buffer.reset();
    }
};

struct audio::device_io::impl : base::impl {
    weak<device_io> weak_device_io;
    audio::device device;
    bool is_running;
    AudioDeviceIOProcID io_proc_id;
    pcm_buffer input_buffer_on_render;
    audio::time input_time_on_render;
    observer<device::change_info> observer;

    impl()
        : weak_device_io(),
          device(nullptr),
          is_running(false),
          io_proc_id(nullptr),
          input_buffer_on_render(nullptr),
          input_time_on_render(nullptr),
          observer(),
          _render_callback(nullptr),
          _maximum_frames(4096),
          _kernel(nullptr),
          _mutex() {
    }

    ~impl() {
        observer.remove_handler(device::system_subject(), device::hardware_did_change_key);

        uninitialize();
    }

    void prepare(device_io const &device_io, audio::device const dev) {
        weak_device_io = to_weak(device_io);

        observer.add_handler(
            device::system_subject(), device::hardware_did_change_key,
            [weak_device_io = weak_device_io](auto const &context) {
                if (auto device_io = weak_device_io.lock()) {
                    if (device_io.device() && !device::device_for_id(device_io.device().audio_device_id())) {
                        device_io.set_device(nullptr);
                    }
                }
            });

        set_device(dev);
    }

    void set_device(audio::device const &dev) {
        if (device != dev) {
            bool running = is_running;

            uninitialize();

            if (device) {
                observer.remove_handler(device.subject(), device::device_did_change_key);
            }

            device = dev;

            if (device) {
                observer.add_handler(device.subject(), device::device_did_change_key,
                                     [weak_device_io = weak_device_io](auto const &context) {
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
        if (!device || io_proc_id) {
            return;
        }

        if (!device.input_format() && !device.output_format()) {
            return;
        }

        auto function = [weak_device_io = weak_device_io](
            const AudioTimeStamp *inNow, const AudioBufferList *inInputData, const AudioTimeStamp *inInputTime,
            AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime) {
            if (outOutputData) {
                audio::clear(outOutputData);
            }

            if (auto device_io = weak_device_io.lock()) {
                auto imp = device_io.impl_ptr<impl>();
                if (auto kernel = imp->kernel()) {
                    kernel->reset_buffers();
                    if (inInputData) {
                        if (auto &input_buffer = kernel->input_buffer) {
                            input_buffer.copy_from(inInputData);

                            UInt32 const input_frame_length = input_buffer.frame_length();
                            if (input_frame_length > 0) {
                                imp->input_buffer_on_render = input_buffer;
                                imp->input_time_on_render =
                                    audio::time(*inInputTime, input_buffer.format().sample_rate());
                            }
                        }
                    }

                    if (auto render_callback = imp->render_callback()) {
                        if (auto &output_buffer = kernel->output_buffer) {
                            if (outOutputData) {
                                UInt32 const frame_length =
                                    audio::frame_length(outOutputData, output_buffer.format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer.set_frame_length(frame_length);
                                    audio::time time(*inOutputTime, output_buffer.format().sample_rate());
                                    render_callback(output_buffer, time);
                                    output_buffer.copy_to(outOutputData);
                                }
                            }
                        } else if (kernel->input_buffer) {
                            pcm_buffer null_buffer;
                            render_callback(null_buffer, nullptr);
                        }
                    }
                }

                imp->input_buffer_on_render = nullptr;
                imp->input_time_on_render = nullptr;
            }
        };

        raise_if_au_error(AudioDeviceCreateIOProcIDWithBlock(&io_proc_id, device.audio_device_id(), nullptr, function));

        update_kernel();
    }

    void uninitialize() {
        stop();

        if (!device || !io_proc_id) {
            return;
        }

        if (device::is_available_device(device)) {
            raise_if_au_error(AudioDeviceDestroyIOProcID(device.audio_device_id(), io_proc_id));
        }

        io_proc_id = nullptr;
        update_kernel();
    }

    void start() {
        is_running = true;

        if (!device || !io_proc_id) {
            return;
        }

        raise_if_au_error(AudioDeviceStart(device.audio_device_id(), io_proc_id));
    }

    void stop() {
        if (!is_running) {
            return;
        }

        is_running = false;

        if (!device || !io_proc_id) {
            return;
        }

        if (device::is_available_device(device)) {
            raise_if_au_error(AudioDeviceStop(device.audio_device_id(), io_proc_id));
        }
    }

    void set_render_callback(render_f &&render_callback) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_callback = std::move(render_callback);
    }

    render_f render_callback() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_callback;
    }

    void set_maximum_frames(UInt32 const frames) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _maximum_frames = frames;
        update_kernel();
    }

    UInt32 maximum_frames() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _maximum_frames;
    }

    void set_kernel(const std::shared_ptr<kernel> &kernel) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = nullptr;
        if (kernel) {
            _kernel = kernel;
        }
    }

    std::shared_ptr<kernel> kernel() const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void update_kernel() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        set_kernel(nullptr);

        if (!device || !io_proc_id) {
            return;
        }

        set_kernel(std::make_shared<device_io::kernel>(device.input_format(), device.output_format(), _maximum_frames));
    }

   private:
    render_f _render_callback;
    UInt32 _maximum_frames;
    std::shared_ptr<device_io::kernel> _kernel;
    mutable std::recursive_mutex _mutex;
};

#pragma mark -

audio::device_io::device_io(std::nullptr_t) : base(nullptr) {
}

audio::device_io::device_io(audio::device const &device) : base(std::make_shared<impl>()) {
    impl_ptr<impl>()->prepare(*this, device);
}

audio::device_io::~device_io() = default;

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
    return impl_ptr<impl>()->device;
}

bool audio::device_io::is_running() const {
    return impl_ptr<impl>()->is_running;
}

void audio::device_io::set_render_callback(render_f callback) {
    impl_ptr<impl>()->set_render_callback(std::move(callback));
}

void audio::device_io::set_maximum_frames_per_slice(UInt32 const frames) {
    impl_ptr<impl>()->set_maximum_frames(frames);
}

UInt32 audio::device_io::maximum_frames_per_slice() const {
    return impl_ptr<impl>()->maximum_frames();
}

void audio::device_io::start() const {
    impl_ptr<impl>()->start();
}

void audio::device_io::stop() const {
    impl_ptr<impl>()->stop();
}

audio::pcm_buffer const &audio::device_io::input_buffer_on_render() const {
    return impl_ptr<impl>()->input_buffer_on_render;
}

audio::time const &audio::device_io::input_time_on_render() const {
    return impl_ptr<impl>()->input_time_on_render;
}

#endif
