//
//  yas_audio_avf_io_core.mm
//

#include "yas_audio_avf_io_core.h"

#if TARGET_OS_IPHONE

#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include "yas_audio_avf_device.h"

using namespace yas;

struct audio::avf_io_core::impl {
    objc_ptr<AVAudioEngine *> _avf_engine;
    objc_ptr<AVAudioSourceNode *> _source_node;
    objc_ptr<AVAudioSinkNode *> _sink_node;

    impl() : _avf_engine(objc_ptr_with_move_object([[AVAudioEngine alloc] init])) {
    }
};

audio::avf_io_core::avf_io_core(avf_device_ptr const &device) : _device(device), _impl(std::make_unique<impl>()) {
}

audio::avf_io_core::~avf_io_core() {
    this->uninitialize();
}

void audio::avf_io_core::initialize() {
    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    auto const &engine = this->_impl->_avf_engine;

    if (output_format) {
        auto const objc_output_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
            initStandardFormatWithSampleRate:output_format->sample_rate()
                                    channels:output_format->channel_count()]);

        [engine.object() connect:this->_impl->_source_node.object()
                              to:this->_impl->_avf_engine.object().outputNode
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

void audio::avf_io_core::uninitialize() {
    this->stop();

    auto const &engine = this->_impl->_avf_engine;
    [engine.object() disconnectNodeInput:this->_impl->_sink_node.object()];
    [engine.object() disconnectNodeOutput:this->_impl->_source_node.object()];

    this->_update_kernel();
}

void audio::avf_io_core::set_render_handler(std::optional<io_render_f> handler) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__render_handler = std::move(handler);
}

void audio::avf_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__maximum_frames = frames;
    this->_update_kernel();
}

bool audio::avf_io_core::start() {
    NSError *error = nil;

    if ([this->_impl->_avf_engine.object() startAndReturnError:&error]) {
        return true;
    } else {
        NSLog(@"%@", error);
        return false;
    }
}

void audio::avf_io_core::stop() {
    [this->_impl->_avf_engine.object() stop];
}

std::optional<audio::pcm_buffer_ptr> const &audio::avf_io_core::input_buffer_on_render() const {
    return this->_input_buffer_on_render;
}

std::optional<audio::time_ptr> const &audio::avf_io_core::input_time_on_render() const {
    return this->_input_time_on_render;
}

void audio::avf_io_core::_prepare(avf_io_core_ptr const &shared) {
    auto weak_io_core = to_weak(shared);

    auto source_node = objc_ptr_with_move_object([[AVAudioSourceNode alloc]
        initWithRenderBlock:[weak_io_core](BOOL *_Nonnull isSilence, const AudioTimeStamp *_Nonnull timestamp,
                                           AVAudioFrameCount frameCount, AudioBufferList *_Nonnull outputData) {
            if (auto io_core = weak_io_core.lock()) {
                if (auto const kernel_opt = io_core->_kernel()) {
                    auto const &kernel = kernel_opt.value();
                    if (auto render_handler = io_core->_render_handler()) {
                        if (auto const &output_buffer_opt = kernel->output_buffer) {
                            auto const &output_buffer = *output_buffer_opt;
                            if (outputData) {
                                uint32_t const frame_length =
                                    audio::frame_length(outputData, output_buffer->format().sample_byte_count());
                                if (frame_length > 0) {
                                    output_buffer->set_frame_length(frame_length);
                                    audio::time time(*timestamp, output_buffer->format().sample_rate());
                                    render_handler.value()(
                                        io_render_args{.output_buffer = output_buffer, .when = std::move(time)});
                                    output_buffer->copy_to(outputData);
                                }
                            }
                        } else if (kernel->input_buffer) {
                            render_handler.value()(io_render_args{.output_buffer = std::nullopt, .when = std::nullopt});
                        }
                    }
                }

                io_core->_input_buffer_on_render = std::nullopt;
                io_core->_input_time_on_render = std::nullopt;
            }

            return OSStatus(noErr);
        }]);

    auto sink_node = objc_ptr_with_move_object([[AVAudioSinkNode alloc]
        initWithReceiverBlock:[weak_io_core](const AudioTimeStamp *_Nonnull timestamp, AVAudioFrameCount frameCount,
                                             const AudioBufferList *_Nonnull inputData) {
            if (auto io_core = weak_io_core.lock()) {
                if (auto kernel_opt = io_core->_kernel()) {
                    auto const &kernel = kernel_opt.value();

                    kernel->reset_buffers();

                    if (inputData) {
                        if (auto const &input_buffer_opt = kernel->input_buffer) {
                            auto const &input_buffer = *input_buffer_opt;

                            input_buffer->copy_from(inputData);

                            uint32_t const input_frame_length = input_buffer->frame_length();
                            if (input_frame_length > 0) {
                                io_core->_input_buffer_on_render = input_buffer;
                                io_core->_input_time_on_render =
                                    std::make_shared<audio::time>(*timestamp, input_buffer->format().sample_rate());
                            }
                        }
                    }
                }
            }
            return OSStatus(noErr);
        }]);

    auto &impl = this->_impl;

    [impl->_avf_engine.object() attachNode:source_node.object()];
    [impl->_avf_engine.object() attachNode:sink_node.object()];

    impl->_source_node = source_node;
    impl->_sink_node = sink_node;
}

std::optional<audio::io_render_f> audio::avf_io_core::_render_handler() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__render_handler;
}

void audio::avf_io_core::_set_kernel(std::optional<io_kernel_ptr> const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = std::nullopt;
    if (kernel) {
        this->__kernel = kernel;
    }
}

std::optional<audio::io_kernel_ptr> audio::avf_io_core::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::avf_io_core::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(std::nullopt);

    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!output_format && !input_format) {
        return;
    }

    this->_set_kernel(io_kernel::make_shared(output_format, input_format, this->__maximum_frames));
}

audio::avf_io_core_ptr audio::avf_io_core::make_shared(avf_device_ptr const &device) {
    auto shared = std::shared_ptr<avf_io_core>(new avf_io_core{device});
    shared->_prepare(shared);
    return shared;
}

#endif
