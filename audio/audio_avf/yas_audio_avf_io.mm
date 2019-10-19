//
//  yas_audio_avf_io.mm
//

#include "yas_audio_avf_io.h"

#if TARGET_OS_IPHONE

#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_io_kernel.h"

using namespace yas;

struct audio::avf_io::impl {
    objc_ptr<AVAudioEngine *> _avf_engine;
    objc_ptr<AVAudioSourceNode *> _source_node;
    objc_ptr<AVAudioSinkNode *> _sink_node;

    impl() : _avf_engine(objc_ptr_with_move_object([[AVAudioEngine alloc] init])) {
    }
};

audio::avf_io::avf_io() : _impl(std::make_unique<impl>()) {
}

audio::avf_io::~avf_io() {
    this->_uninitialize();
}

void audio::avf_io::_initialize() {
    if (!this->_device) {
        return;
    }

    auto const &device = *this->_device;
    auto const &output_format = device->output_format();
    auto const &input_format = device->input_format();

    if (!input_format && !output_format) {
        return;
    }

    auto const &engine = this->_impl->_avf_engine;

    if (output_format) {
        auto const objc_output_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
            initStandardFormatWithSampleRate:output_format->sample_rate()
                                    channels:output_format->channel_count()]);

        [engine.object() connect:this->_impl->_source_node.object()
                              to:this->_impl->_avf_engine.object().mainMixerNode
                          format:objc_output_format.object()];
    }

    if (input_format) {
        auto const objc_input_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
            initStandardFormatWithSampleRate:input_format->sample_rate()
                                    channels:input_format->channel_count()]);

        [engine.object() connect:this->_impl->_avf_engine.object().inputNode
                              to:this->_impl->_sink_node.object()
                          format:objc_input_format.object()];
    }

    this->_update_kernel();
}

void audio::avf_io::_uninitialize() {
    this->stop();

    auto const &engine = this->_impl->_avf_engine;
    [engine.object() disconnectNodeInput:this->_impl->_sink_node.object()];
    [engine.object() disconnectNodeOutput:this->_impl->_source_node.object()];

    if (!this->_device) {
        return;
    }

    this->_update_kernel();
}

void audio::avf_io::set_device(std::optional<avf_device_ptr> const &device) {
    if (this->_device != device) {
        bool const is_running = this->is_running();

        this->_pool.invalidate();

        this->_uninitialize();

        this->_device = device;

        this->_initialize();

        if (device) {
            this->_pool += device.value()
                               ->chain()
                               .perform([weak_io = this->_weak_io](auto const &method) {
                                   if (auto const avf_io = weak_io.lock()) {
                                       switch (method) {
                                           case avf_device::method::route_change:
                                               avf_io->_reload();
                                               break;
                                           case avf_device::method::lost:
                                               avf_io->_uninitialize();
                                               break;
                                       }
                                   }
                               })
                               .end();

            if (is_running) {
                this->start();
            }
        }
    }
}

std::optional<audio::avf_device_ptr> const &audio::avf_io::device() const {
    return this->_device;
}

bool audio::avf_io::is_running() const {
    return this->_impl->_avf_engine.object().isRunning;
}

void audio::avf_io::set_render_handler(render_f handler) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__render_handler = std::move(handler);
}

void audio::avf_io::set_maximum_frames_per_slice(uint32_t const frames) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__maximum_frames = frames;
    this->_update_kernel();
}

uint32_t audio::avf_io::maximum_frames_per_slice() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__maximum_frames;
}

bool audio::avf_io::start() {
    if (this->is_running()) {
        return true;
    }

    auto &impl = this->_impl;

    NSError *error = nil;

    if ([impl->_avf_engine.object() startAndReturnError:&error]) {
        return true;
    } else {
        NSLog(@"%@", error);
        return false;
    }
}

void audio::avf_io::stop() {
    if (!this->is_running()) {
        return;
    }

    auto &impl = this->_impl;

    [impl->_avf_engine.object() stop];
}

std::optional<audio::pcm_buffer_ptr> const &audio::avf_io::input_buffer_on_render() const {
    return this->_input_buffer_on_render;
}

std::optional<audio::time_ptr> const &audio::avf_io::input_time_on_render() const {
    return this->_input_time_on_render;
}

void audio::avf_io::_prepare(avf_io_ptr const &shared) {
    auto &impl = this->_impl;

    auto weak_io = to_weak(shared);
    this->_weak_io = weak_io;

    auto source_node = objc_ptr_with_move_object([[AVAudioSourceNode alloc]
        initWithRenderBlock:[weak_io](BOOL *_Nonnull isSilence, const AudioTimeStamp *_Nonnull timestamp,
                                      AVAudioFrameCount frameCount, AudioBufferList *_Nonnull outputData) {
            if (auto device_io = weak_io.lock()) {
                if (auto kernel = device_io->_kernel()) {
                    if (auto render_handler = device_io->_render_handler()) {
                        if (auto const &output_buffer_opt = kernel->output_buffer) {
                            auto const &output_buffer = *output_buffer_opt;
                            if (outputData) {
                                uint32_t const frame_length =
                                    audio::frame_length(outputData, output_buffer->format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer->set_frame_length(frame_length);
                                    audio::time time(*timestamp, output_buffer->format().sample_rate());
                                    render_handler(
                                        render_args{.output_buffer = output_buffer, .when = std::move(time)});
                                    output_buffer->copy_to(outputData);
                                }
                            }
                        } else if (kernel->input_buffer) {
                            pcm_buffer_ptr null_buffer{nullptr};
                            render_handler(render_args{.output_buffer = null_buffer, .when = std::nullopt});
                        }
                    }
                }

                device_io->_input_buffer_on_render = nullptr;
                device_io->_input_time_on_render = nullptr;
            }

            return OSStatus(noErr);
        }]);

    auto sink_node = objc_ptr_with_move_object([[AVAudioSinkNode alloc]
        initWithReceiverBlock:[weak_io](const AudioTimeStamp *_Nonnull timestamp, AVAudioFrameCount frameCount,
                                        const AudioBufferList *_Nonnull inputData) {
            if (auto device_io = weak_io.lock()) {
                if (auto kernel = device_io->_kernel()) {
                    kernel->reset_buffers();

                    if (inputData) {
                        if (auto const &input_buffer_opt = kernel->input_buffer) {
                            auto const &input_buffer = *input_buffer_opt;

                            input_buffer->copy_from(inputData);

                            uint32_t const input_frame_length = input_buffer->frame_length();
                            if (input_frame_length > 0) {
                                device_io->_input_buffer_on_render = input_buffer;
                                device_io->_input_time_on_render =
                                    std::make_shared<audio::time>(*timestamp, input_buffer->format().sample_rate());
                            }
                        }
                    }
                }
            }
            return OSStatus(noErr);
        }]);

    [impl->_avf_engine.object() attachNode:source_node.object()];
    [impl->_avf_engine.object() attachNode:sink_node.object()];

    impl->_source_node = source_node;
    impl->_sink_node = sink_node;
}

audio::avf_io::render_f audio::avf_io::_render_handler() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__render_handler;
}

void audio::avf_io::_set_kernel(io_kernel_ptr const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = nullptr;
    if (kernel) {
        this->__kernel = kernel;
    }
}

audio::io_kernel_ptr audio::avf_io::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::avf_io::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(nullptr);

    if (!this->_device) {
        return;
    }

    auto const &device = this->_device.value();

    this->_set_kernel(io_kernel::make_shared(device->input_format(), device->output_format(), this->__maximum_frames));
}

void audio::avf_io::_reload() {
    bool const is_running = this->is_running();

    this->_uninitialize();
    this->_initialize();

    if (this->_device && is_running) {
        this->start();
    }
}

audio::avf_io_ptr audio::avf_io::make_shared(std::optional<avf_device_ptr> const &device) {
    auto shared = std::shared_ptr<avf_io>(new avf_io{});
    shared->_prepare(shared);
    shared->set_device(device);
    return shared;
}

#endif
