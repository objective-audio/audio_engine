//
//  yas_audio_ios_io_core.mm
//

#include "yas_audio_ios_io_core.h"

#if TARGET_OS_IPHONE

#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <sstream>
#include "yas_audio_debug.h"
#include "yas_audio_ios_device.h"

using namespace yas;

namespace yas::audio {
static void log_formats(std::string const &prefix, AVAudioFormat const *node_format,
                        audio::format const &device_format) {
    std::ostringstream stream;
    stream << prefix << " - ";
    stream << "node [sample_rate: " << node_format.sampleRate << ", channel_count: " << node_format.channelCount << "]";
    stream << " - ";
    stream << "device [sample_rate: " << device_format.sample_rate()
           << ", channel_count: " << device_format.channel_count() << "]";
    yas_audio_log(stream.str());
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
}

void audio::ios_io_core::uninitialize() {
    this->stop();
}

void audio::ios_io_core::set_render_handler(std::optional<io_render_f> handler) {
    if (this->_render_handler || handler) {
        this->_render_handler = std::move(handler);
        this->_reload_if_needed();
    }
}

void audio::ios_io_core::set_maximum_frames_per_slice(uint32_t const frames) {
    if (this->_maximum_frames != frames) {
        this->_maximum_frames = frames;
        this->_reload_if_needed();
    }
}

bool audio::ios_io_core::start() {
    if (this->_is_started) {
        return true;
    }

    this->_is_started = true;

    if (!this->_create_engine()) {
        return false;
    }

    return this->_start_engine();
}

void audio::ios_io_core::stop() {
    this->_stop_engine();
    this->_dispose_engine();
    this->_is_started = false;
}

audio::io_kernel_ptr audio::ios_io_core::_make_kernel() const {
    auto const &output_format = this->_device->output_format();
    auto const &input_format = this->_device->input_format();

    if (!output_format.has_value() && !input_format.has_value()) {
        return nullptr;
    }

    if (!this->_render_handler) {
        return nullptr;
    }

    if (this->_maximum_frames == 0) {
        return nullptr;
    }

    return io_kernel::make_shared(this->_render_handler.value(), input_format.has_value() ? input_format : std::nullopt,
                                  output_format.has_value() ? output_format : std::nullopt, this->_maximum_frames);
}

bool audio::ios_io_core::_create_engine() {
    if (this->_impl->_avf_engine) {
        return true;
    }

    auto const kernel = this->_make_kernel();
    if (!kernel) {
        return false;
    }

    auto const engine = objc_ptr_with_move_object([[AVAudioEngine alloc] init]);
    this->_impl->_avf_engine = engine;

    if (auto const &output_format = this->_device->output_format()) {
        double const sample_rate = output_format->sample_rate();
        uint32_t const channel_count = output_format->channel_count();

        AVAudioFormat *node_format = [engine.object().outputNode outputFormatForBus:0];

        if (sample_rate == node_format.sampleRate) {
            auto source_node = objc_ptr_with_move_object([[AVAudioSourceNode alloc]
                initWithFormat:node_format
                   renderBlock:[kernel](BOOL *_Nonnull isSilence, const AudioTimeStamp *_Nonnull timestamp,
                                        AVAudioFrameCount frameCount, AudioBufferList *_Nonnull outputData) {
                       if (auto const &output_buffer = kernel->output_buffer) {
                           if (outputData) {
                               uint32_t const frame_length =
                                   audio::frame_length(outputData, output_buffer->format().sample_byte_count());
                               if (frame_length > 0) {
                                   output_buffer->set_frame_length(frame_length);
                                   audio::time time(*timestamp, output_buffer->format().sample_rate());
                                   output_buffer->clear();
                                   kernel->render_handler({.output_buffer = output_buffer.get(),
                                                           .output_time = time,
                                                           .input_buffer = kernel->input_time.has_value() ?
                                                                               kernel->input_buffer.get() :
                                                                               nullptr,
                                                           .input_time = kernel->input_time});
                                   output_buffer->copy_to(outputData);
                               } else {
                                   *isSilence = YES;
                               }
                           } else {
                               *isSilence = YES;
                           }
                       } else {
                           if (auto const &input_buffer = kernel->input_buffer) {
                               audio::time time(*timestamp, input_buffer->format().sample_rate());
                               kernel->render_handler(
                                   {.output_buffer = nullptr,
                                    .output_time = audio::null_time_opt,
                                    .input_buffer = kernel->input_buffer ? kernel->input_buffer.get() : nullptr,
                                    .input_time = std::move(time)});
                           }
                           *isSilence = YES;
                       }

                       kernel->input_time = std::nullopt;

                       return OSStatus(noErr);
                   }]);

            auto const objc_channel_layout =
                objc_ptr_with_move_object([[AVAudioChannelLayout alloc] initWithLayoutTag:channel_count]);
            auto const objc_output_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
                initStandardFormatWithSampleRate:output_format->sample_rate()
                                   channelLayout:objc_channel_layout.object()]);

            [engine.object() attachNode:source_node.object()];
            [engine.object() connect:source_node.object()
                                  to:engine.object().outputNode
                              format:objc_output_format.object()];

            this->_impl->_source_node = source_node;

            log_formats("ios_io_core initialize output connected.", node_format, *output_format);
        } else {
            log_formats("ios_io_core initialize output formats did not match.", node_format, *output_format);
        }
    }

    if (auto const &input_format = this->_device->input_format()) {
        double const sample_rate = input_format->sample_rate();
        uint32_t const channel_count = input_format->channel_count();

        AVAudioFormat *node_format = [engine.object().inputNode inputFormatForBus:0];

        if (sample_rate == node_format.sampleRate) {
            auto sink_node = objc_ptr_with_move_object([[AVAudioSinkNode alloc]
                initWithReceiverBlock:[kernel](const AudioTimeStamp *_Nonnull timestamp, AVAudioFrameCount frameCount,
                                               const AudioBufferList *_Nonnull inputData) {
                    kernel->reset_buffers();
                    kernel->input_time = std::nullopt;

                    if (inputData) {
                        if (auto const &input_buffer = kernel->input_buffer) {
                            input_buffer->copy_from(inputData);

                            uint32_t const input_frame_length = input_buffer->frame_length();
                            if (input_frame_length > 0) {
                                kernel->input_time = audio::time(*timestamp, input_buffer->format().sample_rate());

                                if (!kernel->output_buffer) {
                                    kernel->render_handler({.output_buffer = nullptr,
                                                            .output_time = audio::null_time_opt,
                                                            .input_buffer = input_buffer.get(),
                                                            .input_time = kernel->input_time});
                                    kernel->input_time = std::nullopt;
                                }
                            }
                        }
                    }

                    return OSStatus(noErr);
                }]);

            auto const objc_channel_layout =
                objc_ptr_with_move_object([[AVAudioChannelLayout alloc] initWithLayoutTag:channel_count]);
            auto const objc_input_format = objc_ptr_with_move_object([[AVAudioFormat alloc]
                initStandardFormatWithSampleRate:input_format->sample_rate()
                                   channelLayout:objc_channel_layout.object()]);

            [engine.object() attachNode:sink_node.object()];
            [engine.object() connect:engine.object().inputNode to:sink_node.object() format:objc_input_format.object()];

            this->_impl->_sink_node = sink_node;

            log_formats("ios_io_core initialize input connected.", node_format, *input_format);
        } else {
            log_formats("ios_io_core initialize input formats did not match.", node_format, *input_format);
        }
    }

    return true;
}

void audio::ios_io_core::_dispose_engine() {
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

        this->_impl->_avf_engine = std::nullopt;
    }
}

bool audio::ios_io_core::_start_engine() {
    if (!this->_device->output_format().has_value() && !this->_device->input_format().has_value()) {
        return false;
    }

    auto const engine = this->_impl->_avf_engine;
    if (!engine) {
        yas_audio_log("ios_io_core start() - avf_engine not found.");
        return false;
    }

    auto const objc_engine = engine.value().object();

    if (this->_device->output_format().has_value() && !objc_engine.outputNode) {
        yas_audio_log("ios_io_core start() - outputNode not found.");
        return false;
    }

    if (this->_device->input_format().has_value() && !objc_engine.inputNode) {
        yas_audio_log("ios_io_core start() - inputNode not found.");
        return false;
    }

    NSError *error = nil;
    if ([objc_engine startAndReturnError:&error]) {
        return true;
    } else {
        yas_audio_log(
            ("ios_io_core start() - engine start error : " + to_string((__bridge CFStringRef)error.description)));
        return false;
    }
}

void audio::ios_io_core::_stop_engine() {
    if (auto const &engine = this->_impl->_avf_engine) {
        [engine.value().object() stop];
    }
}

void audio::ios_io_core::_reload_if_needed() {
    bool const is_started = this->_is_started;

    if (is_started) {
        this->stop();
        this->start();
    }
}

audio::ios_io_core_ptr audio::ios_io_core::make_shared(ios_device_ptr const &device) {
    return std::shared_ptr<ios_io_core>(new ios_io_core{device});
}

#endif
