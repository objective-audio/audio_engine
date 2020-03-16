//
//  yas_audio_ios_io_core.mm
//

#include "yas_audio_ios_io_core.h"

#if TARGET_OS_IPHONE

#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <iostream>
#include "yas_audio_ios_device.h"

using namespace yas;

namespace yas::audio {
static void log_invalid_formats(AVAudioFormat const *node_format, audio::format const &device_format) {
    std::cout << "    sample_rate node(" << node_format.sampleRate << ") device(" << device_format.sample_rate() << ")"
              << std::endl;
    std::cout << "    channel_count node(" << node_format.channelCount << ") device(" << device_format.channel_count()
              << ")" << std::endl;
}
}

struct audio::ios_io_core::impl {
    std::optional<objc_ptr<AVAudioEngine *>> _avf_engine = std::nullopt;
    std::optional<objc_ptr<AVAudioSourceNode *>> _source_node = std::nullopt;
    std::optional<objc_ptr<AVAudioSinkNode *>> _sink_node = std::nullopt;
};

audio::ios_io_core::ios_io_core(ios_device_ptr const &device) : _device(device), _impl(std::make_unique<impl>()) {
}

audio::ios_io_core::~ios_io_core() {
    this->uninitialize();
}

void audio::ios_io_core::initialize() {
    auto engine = objc_ptr_with_move_object([[AVAudioEngine alloc] init]);
    this->_impl->_avf_engine = engine;

    if (auto const &output_format = this->_device->output_format()) {
        double const sample_rate = output_format->sample_rate();
        uint32_t const channel_count = output_format->channel_count();

        AVAudioFormat *node_format = [engine.object().outputNode outputFormatForBus:0];

        if (sample_rate == node_format.sampleRate && channel_count == node_format.channelCount) {
            auto source_node = objc_ptr_with_move_object([[AVAudioSourceNode alloc]
                initWithRenderBlock:[weak_io_core = this->_weak_core](
                                        BOOL *_Nonnull isSilence, const AudioTimeStamp *_Nonnull timestamp,
                                        AVAudioFrameCount frameCount, AudioBufferList *_Nonnull outputData) {
                    if (auto io_core = weak_io_core.lock()) {
                        if (auto const kernel_opt = io_core->_kernel()) {
                            auto const &kernel = kernel_opt.value();
                            if (auto render_handler = io_core->_render_handler()) {
                                if (auto const &output_buffer_opt = kernel->output_buffer) {
                                    auto const &output_buffer = *output_buffer_opt;
                                    if (outputData) {
                                        uint32_t const frame_length = audio::frame_length(
                                            outputData, output_buffer->format().sample_byte_count());
                                        if (frame_length > 0) {
                                            output_buffer->set_frame_length(frame_length);
                                            audio::time time(*timestamp, output_buffer->format().sample_rate());
                                            output_buffer->clear();
                                            render_handler.value()(io_render_args{.output_buffer = output_buffer,
                                                                                  .when = std::move(time)});
                                            output_buffer->copy_to(outputData);
                                        }
                                    }
                                } else if (kernel->input_buffer) {
                                    render_handler.value()(
                                        io_render_args{.output_buffer = std::nullopt, .when = std::nullopt});
                                }
                            }
                        }

                        io_core->_input_buffer_on_render = std::nullopt;
                        io_core->_input_time_on_render = std::nullopt;
                    }

                    return OSStatus(noErr);
                }]);

            auto const objc_output_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
                initStandardFormatWithSampleRate:output_format->sample_rate()
                                        channels:output_format->channel_count()]);

            [engine.object() attachNode:source_node.object()];
            [engine.object() connect:source_node.object()
                                  to:engine.object().outputNode
                              format:objc_output_format.object()];

            this->_impl->_source_node = source_node;
        } else {
            std::cout << "ios_io_core output node format is not equal to output device format." << std::endl;
            log_invalid_formats(node_format, *output_format);
        }
    }

    if (auto const &input_format = this->_device->input_format()) {
        double const sample_rate = input_format->sample_rate();
        uint32_t const channel_count = input_format->channel_count();

        AVAudioFormat *node_format = [engine.object().inputNode inputFormatForBus:0];

        if (sample_rate == node_format.sampleRate && channel_count == node_format.channelCount) {
            auto sink_node = objc_ptr_with_move_object([[AVAudioSinkNode alloc]
                initWithReceiverBlock:[weak_io_core = this->_weak_core](const AudioTimeStamp *_Nonnull timestamp,
                                                                        AVAudioFrameCount frameCount,
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
                                        io_core->_input_time_on_render = std::make_shared<audio::time>(
                                            *timestamp, input_buffer->format().sample_rate());

                                        if (!kernel->output_buffer) {
                                            if (auto render_handler = io_core->_render_handler()) {
                                                render_handler.value()(io_render_args{.output_buffer = std::nullopt,
                                                                                      .when = std::nullopt});
                                                io_core->_input_buffer_on_render = std::nullopt;
                                                io_core->_input_time_on_render = std::nullopt;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return OSStatus(noErr);
                }]);

            auto const objc_input_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
                initStandardFormatWithSampleRate:input_format->sample_rate()
                                        channels:input_format->channel_count()]);

            [engine.object() attachNode:sink_node.object()];
            [engine.object() connect:engine.object().inputNode to:sink_node.object() format:objc_input_format.object()];

            this->_impl->_sink_node = sink_node;
        } else {
            std::cout << "ios_io_core output node format is not equal to input device format." << std::endl;
            log_invalid_formats(node_format, *input_format);
        }
    }

    this->_update_kernel();
}

void audio::ios_io_core::uninitialize() {
    this->stop();

    if (auto const &engine_opt = this->_impl->_avf_engine) {
        auto const &engine = engine_opt.value();

        if (auto const &sink_node_opt = this->_impl->_sink_node) {
            auto const &sink_node = sink_node_opt.value();
            if ([engine.object().attachedNodes containsObject:sink_node.object()]) {
                [engine.object() disconnectNodeInput:sink_node.object()];
                [engine.object() detachNode:sink_node.object()];
            }
            this->_impl->_sink_node = std::nullopt;
        }

        if (auto const &source_node_opt = this->_impl->_source_node) {
            auto const &source_node = source_node_opt.value();
            if ([engine.object().attachedNodes containsObject:source_node.object()]) {
                [engine.object() disconnectNodeInput:source_node.object()];
                [engine.object() detachNode:source_node.object()];
            }
            this->_impl->_source_node = std::nullopt;
        }

        this->_impl->_avf_engine = nullptr;
    }

    this->_update_kernel();
}

void audio::ios_io_core::set_render_handler(std::optional<io_render_f> handler) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__render_handler = std::move(handler);
}

void audio::ios_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__maximum_frames = frames;
    this->_update_kernel();
}

bool audio::ios_io_core::start() {
    NSError *error = nil;
    auto const engine = this->_impl->_avf_engine;

    if (engine && [engine.value().object() startAndReturnError:&error]) {
        return true;
    } else {
        NSLog(@"%@", error);
        return false;
    }
}

void audio::ios_io_core::stop() {
    if (auto const &engine = this->_impl->_avf_engine) {
        [engine.value().object() stop];
    }
}

std::optional<audio::pcm_buffer_ptr> const &audio::ios_io_core::input_buffer_on_render() const {
    return this->_input_buffer_on_render;
}

std::optional<audio::time_ptr> const &audio::ios_io_core::input_time_on_render() const {
    return this->_input_time_on_render;
}

void audio::ios_io_core::_prepare(ios_io_core_ptr const &shared) {
    this->_weak_core = shared;
}

std::optional<audio::io_render_f> audio::ios_io_core::_render_handler() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__render_handler;
}

void audio::ios_io_core::_set_kernel(std::optional<io_kernel_ptr> const &kernel) {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    this->__kernel = std::nullopt;
    if (kernel) {
        this->__kernel = kernel;
    }
}

std::optional<audio::io_kernel_ptr> audio::ios_io_core::_kernel() const {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);
    return this->__kernel;
}

void audio::ios_io_core::_update_kernel() {
    std::lock_guard<std::recursive_mutex> lock(this->_mutex);

    this->_set_kernel(std::nullopt);

    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    bool const output_available = output_format.has_value() && this->_impl->_source_node.has_value();
    bool const input_available = input_format.has_value() && this->_impl->_sink_node.has_value();

    if (!output_available && !input_available) {
        return;
    }

    this->_set_kernel(io_kernel::make_shared(input_available ? input_format : std::nullopt,
                                             output_available ? output_format : std::nullopt, this->__maximum_frames));
}

audio::ios_io_core_ptr audio::ios_io_core::make_shared(ios_device_ptr const &device) {
    auto shared = std::shared_ptr<ios_io_core>(new ios_io_core{device});
    shared->_prepare(shared);
    return shared;
}

#endif
