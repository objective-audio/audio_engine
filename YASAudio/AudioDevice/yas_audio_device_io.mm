//
//  yas_audio_device_io.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_device_io.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device.h"
#include "yas_audio_data.h"
#include "yas_audio_format.h"
#include "yas_audio_time.h"
#include "yas_observing.h"
#include "yas_exception.h"
#include <memory>
#include <mutex>
#include <Foundation/Foundation.h>

using namespace yas;

class audio_device_io::impl
{
   public:
    class kernel
    {
       public:
        audio_data_ptr input_data;
        audio_data_ptr output_data;

        kernel(const audio_format_ptr &input_format, const audio_format_ptr &output_format, const UInt32 frame_capacity)
            : input_data(input_format ? audio_data::create(input_format, frame_capacity) : nullptr),
              output_data(output_format ? audio_data::create(output_format, frame_capacity) : nullptr)
        {
        }

        void clear()
        {
            if (input_data) {
                input_data->clear();
            }
            if (output_data) {
                output_data->clear();
            }
        }
    };

    using kernel_ptr = std::shared_ptr<kernel>;

    audio_device_ptr audio_device;
    bool is_running;
    AudioDeviceIOProcID io_proc_id;
    audio_data_ptr input_data_on_render;
    audio_time_ptr input_time_on_render;
    audio_device_observer_ptr observer;

    impl(const audio_device_ptr audio_device)
        : audio_device(audio_device),
          is_running(false),
          io_proc_id(nullptr),
          input_data_on_render(nullptr),
          input_time_on_render(nullptr),
          observer(audio_device_observer::create()),
          _render_callback(nullptr),
          _maximum_frames(4096),
          _kernel(nullptr),
          _mutex()
    {
    }

    void set_render_callback(const render_function &render_callback)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_callback = render_callback;
    }

    render_function render_callback() const
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

    void set_kernel(const kernel_ptr &kernel)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = nullptr;
        if (kernel) {
            _kernel = kernel;
        }
    }

    kernel_ptr kernel() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
    }

    void update_kernel()
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        set_kernel(nullptr);

        if (!audio_device || !io_proc_id) {
            return;
        }

        set_kernel(std::make_shared<class kernel>(audio_device->input_format(), audio_device->output_format(),
                                                  _maximum_frames));
    }

   private:
    render_function _render_callback;
    UInt32 _maximum_frames;
    kernel_ptr _kernel;
    mutable std::recursive_mutex _mutex;
};

audio_device_io_ptr audio_device_io::create()
{
    return audio_device_io::create(nullptr);
}

audio_device_io_ptr audio_device_io::create(const audio_device_ptr &audio_device)
{
    auto device_io = std::shared_ptr<audio_device_io>(new audio_device_io(audio_device));
    std::weak_ptr<audio_device_io> weak_device_io = device_io->shared_from_this();
    device_io->_impl->observer->add_handler(
        audio_device::system_subject(), audio_device::method::hardware_did_change,
        [weak_device_io](const auto &method, const auto &infos) {
            if (auto device_io = weak_device_io.lock()) {
                if (device_io->audio_device() &&
                    !audio_device::device_for_id(device_io->audio_device()->audio_device_id())) {
                    device_io->set_audio_device(nullptr);
                }
            }
        });
    return device_io;
}

audio_device_io::audio_device_io(const audio_device_ptr &audio_device) : _impl(std::make_unique<impl>(audio_device))
{
}

audio_device_io::~audio_device_io()
{
    _impl->observer->remove_handler(audio_device::system_subject(), audio_device::method::hardware_did_change);

    uninitialize();
}

void audio_device_io::initialize()
{
    if (!_impl->audio_device || _impl->io_proc_id) {
        return;
    }

    if (!_impl->audio_device->input_format() && !_impl->audio_device->output_format()) {
        return;
    }

    std::weak_ptr<audio_device_io> weak_device_io = this->shared_from_this();

    yas_raise_if_au_error(AudioDeviceCreateIOProcIDWithBlock(
        &_impl->io_proc_id, _impl->audio_device->audio_device_id(), nullptr,
        ^(const AudioTimeStamp *inNow, const AudioBufferList *inInputData, const AudioTimeStamp *inInputTime,
          AudioBufferList *outOutputData, const AudioTimeStamp *inOutputTime) {
            if (outOutputData) {
                clear(outOutputData);
            }

            if (auto device_io = weak_device_io.lock()) {
                if (auto kernel = device_io->_impl->kernel()) {
                    kernel->clear();
                    if (inInputData) {
                        if (auto &input_data = kernel->input_data) {
                            copy_data_flexibly(inInputData, input_data);

                            const UInt32 input_frame_length = input_data->frame_length();
                            if (input_frame_length > 0) {
                                device_io->_impl->input_data_on_render = input_data;
                                device_io->_impl->input_time_on_render =
                                    std::make_shared<audio_time>(*inInputTime, input_data->format()->sample_rate());
                            }
                        }
                    }

                    auto render_callback = device_io->_impl->render_callback();
                    if (render_callback) {
                        if (auto &output_data = kernel->output_data) {
                            if (outOutputData) {
                                const UInt32 frame_length =
                                    yas::frame_length(outOutputData, output_data->format()->sample_byte_count());
                                if (frame_length > 0) {
                                    output_data->set_frame_length(frame_length);
                                    auto time = std::make_shared<audio_time>(*inOutputTime,
                                                                             output_data->format()->sample_rate());
                                    render_callback(output_data, time);
                                    copy_data_flexibly(output_data, outOutputData);
                                }
                            }
                        } else if (kernel->input_data) {
                            audio_data_ptr data = nullptr;
                            audio_time_ptr time = nullptr;
                            render_callback(data, time);
                        }
                    }
                }

                device_io->_impl->input_data_on_render = nullptr;
                device_io->_impl->input_time_on_render = nullptr;
            }
        }));

    _impl->update_kernel();
}

void audio_device_io::uninitialize()
{
    stop();

    if (!_impl->audio_device || !_impl->io_proc_id) {
        return;
    }

    yas_raise_if_au_error(AudioDeviceDestroyIOProcID(_impl->audio_device->audio_device_id(), _impl->io_proc_id));

    _impl->io_proc_id = nullptr;
    _impl->update_kernel();
}

void audio_device_io::set_audio_device(const audio_device_ptr device)
{
    if (_impl->audio_device != device) {
        bool running = is_running();

        uninitialize();

        if (_impl->audio_device) {
            _impl->observer->remove_handler(_impl->audio_device->property_subject(),
                                            audio_device::method::device_did_change);
        }

        _impl->audio_device = device;

        if (device) {
            std::weak_ptr<audio_device_io> weak_device_io = this->shared_from_this();
            _impl->observer->add_handler(_impl->audio_device->property_subject(),
                                         audio_device::method::device_did_change,
                                         [weak_device_io](const auto &method, const auto &infos) {
                                             if (auto device_io = weak_device_io.lock()) {
                                                 device_io->_impl->update_kernel();
                                             }
                                         });
        }

        initialize();

        if (running) {
            start();
        }
    }
}

audio_device_ptr audio_device_io::audio_device() const
{
    return _impl->audio_device;
}

bool audio_device_io::is_running() const
{
    return _impl->is_running;
}

void audio_device_io::set_render_callback(const render_function &callback)
{
    _impl->set_render_callback(callback);
}

void audio_device_io::set_maximum_frames_per_slice(const UInt32 frames)
{
    _impl->set_maximum_frames(frames);
}

UInt32 audio_device_io::maximum_frames_per_slice() const
{
    return _impl->maximum_frames();
}

void audio_device_io::start()
{
    _impl->is_running = YES;

    if (!_impl->audio_device || !_impl->io_proc_id) {
        return;
    }

    yas_raise_if_au_error(AudioDeviceStart(_impl->audio_device->audio_device_id(), _impl->io_proc_id));
}

void audio_device_io::stop()
{
    if (!_impl->is_running) {
        return;
    }

    _impl->is_running = NO;

    if (!_impl->audio_device || !_impl->io_proc_id) {
        return;
    }

    yas_raise_if_au_error(AudioDeviceStop(_impl->audio_device->audio_device_id(), _impl->io_proc_id));
}

const audio_data_ptr audio_device_io::input_data_on_render() const
{
    return _impl->input_data_on_render;
}

const audio_time_ptr audio_device_io::input_time_on_render() const
{
    return _impl->input_time_on_render;
}

#endif
