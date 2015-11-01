//
//  yas_audio_device_io.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_io.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_audio_time.h"
#include "yas_observing.h"
#include "yas_exception.h"
#include <memory>
#include <mutex>

using namespace yas;

class audio_device_io::kernel
{
   public:
    audio_pcm_buffer input_buffer;
    audio_pcm_buffer output_buffer;

    kernel(const audio_format &input_format, const audio_format &output_format, const UInt32 frame_capacity)
        : input_buffer(input_format ? audio_pcm_buffer(input_format, frame_capacity) : nullptr),
          output_buffer(output_format ? audio_pcm_buffer(output_format, frame_capacity) : nullptr)
    {
    }

    void reset_buffers()
    {
        input_buffer.reset();
        output_buffer.reset();
    }
};

class audio_device_io::impl : public base::impl
{
   public:
    weak<audio_device_io> weak_device_io;
    audio_device device;
    bool is_running;
    AudioDeviceIOProcID io_proc_id;
    audio_pcm_buffer input_buffer_on_render;
    audio_time input_time_on_render;
    observer observer;

    impl()
        : weak_device_io(),
          device(nullptr),
          is_running(false),
          io_proc_id(nullptr),
          input_buffer_on_render(nullptr),
          input_time_on_render(),
          observer(),
          _render_callback(nullptr),
          _maximum_frames(4096),
          _kernel(nullptr),
          _mutex()
    {
    }

    ~impl()
    {
        observer.remove_handler(audio_device::system_subject(), audio_device_method::hardware_did_change);

        uninitialize();
    }

    void prepare(const audio_device_io &device_io, const audio_device dev)
    {
        weak_device_io = to_weak(device_io);

        observer.add_handler(
            audio_device::system_subject(), audio_device_method::hardware_did_change,
            [weak_device_io = weak_device_io](const auto &method, const auto &infos) {
                if (auto device_io = weak_device_io.lock()) {
                    if (device_io.device() && !audio_device::device_for_id(device_io.device().audio_device_id())) {
                        device_io.set_device(nullptr);
                    }
                }
            });

        set_device(dev);
    }

    void set_device(const audio_device &dev)
    {
        if (device != dev) {
            bool running = is_running;

            uninitialize();

            if (device) {
                observer.remove_handler(device.property_subject(), audio_device_method::device_did_change);
            }

            device = dev;

            if (device) {
                observer.add_handler(device.property_subject(), audio_device_method::device_did_change,
                                     [weak_device_io = weak_device_io](const auto &method, const auto &infos) {
                                         if (auto device_io = weak_device_io.lock()) {
                                             device_io._impl_ptr()->update_kernel();
                                         }
                                     });
            }

            initialize();

            if (running) {
                start();
            }
        }
    }

    void initialize()
    {
        if (!device || io_proc_id) {
            return;
        }

        if (!device.input_format() && !device.output_format()) {
            return;
        }

        auto function = [weak_device_io = weak_device_io](
            const AudioTimeStamp *inNow, const AudioBufferList *inInputData, const AudioTimeStamp *inInputTime,
            AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime)
        {
            if (outOutputData) {
                clear(outOutputData);
            }

            if (auto device_io = weak_device_io.lock()) {
                auto impl = device_io._impl_ptr();
                if (auto kernel = impl->kernel()) {
                    kernel->reset_buffers();
                    if (inInputData) {
                        if (auto &input_buffer = kernel->input_buffer) {
                            input_buffer.copy_from(inInputData);

                            const UInt32 input_frame_length = input_buffer.frame_length();
                            if (input_frame_length > 0) {
                                impl->input_buffer_on_render = input_buffer;
                                impl->input_time_on_render =
                                    audio_time(*inInputTime, input_buffer.format().sample_rate());
                            }
                        }
                    }

                    if (auto render_callback = impl->render_callback()) {
                        if (auto &output_buffer = kernel->output_buffer) {
                            if (outOutputData) {
                                const UInt32 frame_length =
                                    yas::frame_length(outOutputData, output_buffer.format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer.set_frame_length(frame_length);
                                    audio_time time(*inOutputTime, output_buffer.format().sample_rate());
                                    render_callback(output_buffer, time);
                                    output_buffer.copy_to(outOutputData);
                                }
                            }
                        } else if (kernel->input_buffer) {
                            yas::audio_pcm_buffer null_buffer;
                            render_callback(null_buffer, nullptr);
                        }
                    }
                }

                impl->input_buffer_on_render = nullptr;
                impl->input_time_on_render = nullptr;
            }
        };

        yas_raise_if_au_error(
            AudioDeviceCreateIOProcIDWithBlock(&io_proc_id, device.audio_device_id(), nullptr, function));

        update_kernel();
    }

    void uninitialize()
    {
        stop();

        if (!device || !io_proc_id) {
            return;
        }

        yas_raise_if_au_error(AudioDeviceDestroyIOProcID(device.audio_device_id(), io_proc_id));

        io_proc_id = nullptr;
        update_kernel();
    }

    void start()
    {
        is_running = true;

        if (!device || !io_proc_id) {
            return;
        }

        yas_raise_if_au_error(AudioDeviceStart(device.audio_device_id(), io_proc_id));
    }

    void stop()
    {
        if (!is_running) {
            return;
        }

        is_running = false;

        if (!device || !io_proc_id) {
            return;
        }

        yas_raise_if_au_error(AudioDeviceStop(device.audio_device_id(), io_proc_id));
    }

    void set_render_callback(const render_f &render_callback)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_callback = render_callback;
    }

    render_f render_callback() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_callback;
    }

    void set_maximum_frames(const UInt32 frames)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _maximum_frames = frames;
        update_kernel();
    }

    UInt32 maximum_frames() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _maximum_frames;
    }

    void set_kernel(const std::shared_ptr<kernel> &kernel)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = nullptr;
        if (kernel) {
            _kernel = kernel;
        }
    }

    std::shared_ptr<kernel> kernel() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void update_kernel()
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        set_kernel(nullptr);

        if (!device || !io_proc_id) {
            return;
        }

        set_kernel(
            std::make_shared<audio_device_io::kernel>(device.input_format(), device.output_format(), _maximum_frames));
    }

   private:
    render_f _render_callback;
    UInt32 _maximum_frames;
    std::shared_ptr<audio_device_io::kernel> _kernel;
    mutable std::recursive_mutex _mutex;
};

#pragma mark -

audio_device_io::audio_device_io(std::nullptr_t) : super_class(nullptr)
{
}

audio_device_io::audio_device_io(const audio_device &device) : super_class(std::make_shared<impl>())
{
    _impl_ptr()->prepare(*this, device);
}

audio_device_io::~audio_device_io() = default;

void audio_device_io::_initialize()
{
    _impl_ptr()->initialize();
}

void audio_device_io::_uninitialize()
{
    _impl_ptr()->uninitialize();
}

void audio_device_io::set_device(const audio_device device)
{
    _impl_ptr()->set_device(device);
}

audio_device audio_device_io::device() const
{
    return _impl_ptr()->device;
}

bool audio_device_io::is_running() const
{
    return _impl_ptr()->is_running;
}

void audio_device_io::set_render_callback(const render_f &callback)
{
    _impl_ptr()->set_render_callback(callback);
}

void audio_device_io::set_maximum_frames_per_slice(const UInt32 frames)
{
    _impl_ptr()->set_maximum_frames(frames);
}

UInt32 audio_device_io::maximum_frames_per_slice() const
{
    return _impl_ptr()->maximum_frames();
}

void audio_device_io::start()
{
    _impl_ptr()->start();
}

void audio_device_io::stop()
{
    _impl_ptr()->stop();
}

const audio_pcm_buffer &audio_device_io::input_buffer_on_render() const
{
    return _impl_ptr()->input_buffer_on_render;
}

const audio_time &audio_device_io::input_time_on_render() const
{
    return _impl_ptr()->input_time_on_render;
}

std::shared_ptr<audio_device_io::impl> audio_device_io::_impl_ptr() const
{
    return impl_ptr<impl>();
}

#endif
