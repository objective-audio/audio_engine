//
//  yas_audio_engine_avf_au.mm
//

#include "yas_audio_engine_avf_au.h"
#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_fast_each.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_thread.h>
#include <iostream>
#include "yas_audio_time.h"

using namespace yas;

struct audio::engine::avf_au::core {
    using input_f = std::function<AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags,
                                                    AudioTimeStamp const *timestamp, AUAudioFrameCount frameCount,
                                                    NSInteger inputBusNumber, AudioBufferList *inputData)>;

    void load_raw_unit(AudioComponentDescription const &acd, avf_au_ptr const &shared) {
        auto weak_au = to_weak(shared);

        [AUAudioUnit instantiateWithComponentDescription:acd
                                                 options:kAudioComponentInstantiation_LoadOutOfProcess
                                       completionHandler:^(AUAudioUnit *_Nullable audioUnit, NSError *_Nullable error) {
                                           assert(thread::is_main());
                                           if (auto const shared_au = weak_au.lock()) {
                                               if (error) {
                                                   auto error_message =
                                                       to_string((__bridge CFStringRef)error.description);
                                                   std::cout << "load raw unit error : " << error_message << std::endl;
                                                   shared_au->_load_state->set_value(load_state::failed);
                                               } else {
                                                   shared_au->_core->set_raw_unit(objc_ptr<AUAudioUnit *>{audioUnit});
                                                   shared_au->_setup();
                                                   shared_au->_load_state->set_value(load_state::loaded);
                                               }
                                           }
                                       }];
    }

    std::optional<objc_ptr<AUAudioUnit *>> raw_unit() const {
        std::lock_guard<std::recursive_mutex> lock(this->_unit_mutex);
        return this->_raw_unit;
    }

    std::optional<input_f> input_block() const {
        std::lock_guard<std::recursive_mutex> lock(this->_input_mutex);
        return this->_input_block;
    }

    void set_input_block(std::optional<input_f> &&block) {
        std::lock_guard<std::recursive_mutex> lock(this->_input_mutex);
        this->_input_block = block;
    }

   private:
    mutable std::recursive_mutex _unit_mutex;
    std::optional<objc_ptr<AUAudioUnit *>> _raw_unit = std::nullopt;
    mutable std::recursive_mutex _input_mutex;
    std::optional<input_f> _input_block = std::nullopt;

    void set_raw_unit(objc_ptr<AUAudioUnit *> &&raw_unit) {
        std::lock_guard<std::recursive_mutex> lock(this->_unit_mutex);
        this->_raw_unit = std::move(raw_unit);
    }
};

audio::engine::avf_au::avf_au(node_args &&args)
    : _node(node::make_shared(std::move(args))), _core(std::make_unique<core>()) {
}

audio::engine::avf_au::~avf_au() = default;

audio::engine::avf_au::load_state audio::engine::avf_au::state() const {
    return this->_load_state->raw();
}

void audio::engine::avf_au::set_input_bus_count(uint32_t const count) {
    auto const raw_unit = this->_core->raw_unit();
    AUAudioUnitBusArray *inputBusses = raw_unit.value().object().inputBusses;
    if (inputBusses.isCountChangeable) {
        NSError *error = nil;
        if (![inputBusses setBusCount:count error:&error]) {
            auto error_message = to_string((__bridge CFStringRef)error.description);
            std::cout << "set input element count error : " << error_message << std::endl;
        }
    } else {
        std::cout << "input element count is not changable." << std::endl;
    }
}

void audio::engine::avf_au::set_output_bus_count(uint32_t const count) {
    auto const raw_unit = this->_core->raw_unit();
    AUAudioUnitBusArray *outputBusses = raw_unit.value().object().outputBusses;
    if (outputBusses.isCountChangeable) {
        NSError *error = nil;
        if (![outputBusses setBusCount:count error:&error]) {
            auto error_message = to_string((__bridge CFStringRef)error.description);
            std::cout << "set output element count error : " << error_message << std::endl;
        }
    } else {
        std::cout << "output element count is not changable." << std::endl;
    }
}

uint32_t audio::engine::avf_au::input_bus_count() const {
    auto const raw_unit = this->_core->raw_unit();
    return (uint32_t)raw_unit.value().object().inputBusses.count;
}

uint32_t audio::engine::avf_au::output_bus_count() const {
    auto const raw_unit = this->_core->raw_unit();
    return (uint32_t)raw_unit.value().object().outputBusses.count;
}

void audio::engine::avf_au::_initialize_raw_unit() {
    NSError *error = nil;

    if (auto const raw_unit = this->_core->raw_unit()) {
        if (![raw_unit.value().object() allocateRenderResourcesAndReturnError:&error]) {
            auto error_message = to_string((__bridge CFStringRef)error.description);
            std::cout << "allocateRenderResources error : " << error_message << std::endl;
        }
    }
}

void audio::engine::avf_au::_uninitialize_raw_unit() {
    if (auto const raw_unit = this->_core->raw_unit()) {
        [raw_unit.value().object() deallocateRenderResources];
    }
}

void audio::engine::avf_au::set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
    this->_set_parameter_value(kAudioUnitScope_Global, parameter_id, value, 0);
}

float audio::engine::avf_au::global_parameter_value(AudioUnitParameterID const parameter_id) const {
    return this->_get_parameter_value(kAudioUnitScope_Global, parameter_id, 0);
}

void audio::engine::avf_au::set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                      AudioUnitElement const element) {
    this->_set_parameter_value(kAudioUnitScope_Input, parameter_id, value, element);
}

float audio::engine::avf_au::input_parameter_value(AudioUnitParameterID const parameter_id,
                                                   AudioUnitElement const element) const {
    return this->_get_parameter_value(kAudioUnitScope_Input, parameter_id, element);
}

void audio::engine::avf_au::set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                                       AudioUnitElement const element) {
    this->_set_parameter_value(kAudioUnitScope_Output, parameter_id, value, element);
}

float audio::engine::avf_au::output_parameter_value(AudioUnitParameterID const parameter_id,
                                                    AudioUnitElement const element) const {
    return this->_get_parameter_value(kAudioUnitScope_Output, parameter_id, element);
}

audio::engine::node_ptr const &audio::engine::avf_au::node() const {
    return this->_node;
}

chaining::chain_sync_t<audio::engine::avf_au::load_state> audio::engine::avf_au::load_state_chain() const {
    return this->_load_state->chain();
}

chaining::chain_unsync_t<audio::engine::avf_au::connection_method> audio::engine::avf_au::connection_chain() const {
    return this->_connection_notifier->chain();
}

void audio::engine::avf_au::_prepare(avf_au_ptr const &shared, AudioComponentDescription const &acd) {
    this->_weak_au = shared;
    this->_acd = acd;

    auto weak_au = to_weak(shared);

    this->_node->set_render_handler([weak_au](node::render_args args) {
        auto &buffer = args.buffer;

        if (auto au = weak_au.lock()) {
            auto const raw_unit = au->_core->raw_unit();
            auto const input_block = au->_core->input_block();
            if (raw_unit && input_block) {
                AudioUnitRenderActionFlags action_flags = 0;
                AudioTimeStamp const time_stamp = args.when.audio_time_stamp();

                raw_unit.value().object().renderBlock(
                    &action_flags, &time_stamp, buffer->frame_length(), args.bus_idx, buffer->audio_buffer_list(),
                    ^AUAudioUnitStatus(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp,
                                       AUAudioFrameCount frameCount, NSInteger inputBusNumber,
                                       AudioBufferList *inputData) {
                        return input_block.value()(actionFlags, timestamp, frameCount, inputBusNumber, inputData);
                    });
            }
        }
    });

    this->_core->set_input_block(
        [weak_au = this->_weak_au](AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp,
                                   AUAudioFrameCount frameCount, NSInteger inputBusNumber, AudioBufferList *inputData) {
            if (auto au = weak_au.lock()) {
                if (auto kernel = au->node()->kernel()) {
                    if (auto connection = kernel.value()->input_connection((uint32_t)inputBusNumber)) {
                        if (auto src_node = connection->source_node()) {
                            auto const buffer = std::make_shared<pcm_buffer>(connection->format, inputData);
                            buffer->clear();
                            time when(*timestamp, connection->format.sample_rate());
                            src_node->render({.buffer = buffer, .bus_idx = connection->source_bus, .when = when});
                        }
                    }
                }
            }
            return (AUAudioUnitStatus)noErr;
        });

    this->_pool += this->_node->chain(node::method::will_reset)
                       .perform([weak_au](auto const &) {
                           if (auto au = weak_au.lock()) {
                               au->_will_reset();
                           }
                       })
                       .end();

    this->_pool += this->_node->chain(node::method::update_connections)
                       .perform([weak_au](auto const &) {
                           if (auto au = weak_au.lock()) {
                               au->_update_unit_connections();
                           }
                       })
                       .end();

    manageable_node::cast(this->_node)->set_add_to_graph_handler([weak_au](audio::graph &graph) {
        if (auto au = weak_au.lock()) {
            au->_initialize_raw_unit();
        }
    });

    manageable_node::cast(this->_node)->set_remove_from_graph_handler([weak_au](audio::graph &graph) {
        if (auto au = weak_au.lock()) {
            au->_uninitialize_raw_unit();
        }
    });

    this->_core->load_raw_unit(acd, shared);
}

void audio::engine::avf_au::_setup() {
    auto const raw_unit = this->_core->raw_unit();
    raw_unit.value().object().maximumFramesToRender = 4096;
}

void audio::engine::avf_au::_will_reset() {
    if (auto const raw_unit = this->_core->raw_unit()) {
        [raw_unit.value().object() reset];
    }
}

void audio::engine::avf_au::_update_unit_connections() {
    if (auto const raw_unit_opt = this->_core->raw_unit()) {
        auto const &raw_unit = raw_unit_opt.value();

        bool const is_initialized = raw_unit.object().renderResourcesAllocated;

        if (is_initialized) {
            this->_uninitialize_raw_unit();
        }

        this->_connection_notifier->notify(connection_method::will_update);

        auto const input_bus_count = this->input_bus_count();
        if (input_bus_count > 0) {
            auto each = make_fast_each(input_bus_count);
            while (yas_each_next(each)) {
                uint32_t const bus_idx = yas_each_index(each);

                AUAudioUnitBus *bus = raw_unit.object().inputBusses[bus_idx];
                bus.enabled = NO;

                if (auto connection = manageable_node::cast(this->_node)->input_connection(bus_idx)) {
                    NSError *error = nil;
                    auto const format = objc_ptr_with_move_object(
                        [[AVAudioFormat alloc] initWithStreamDescription:&connection->format.stream_description()]);
                    if ([bus setFormat:format.object() error:&error]) {
                        bus.enabled = YES;
                    } else {
                        auto component_name = to_string((__bridge CFStringRef)raw_unit.object().componentName);
                        auto error_message = to_string((__bridge CFStringRef)error.description);
                        std::cout << component_name << " bus_idx : " << bus_idx
                                  << " set input format - error : " << error_message << std::endl;
                    }
                }
            }
        } else {
            this->_core->set_input_block(std::nullopt);
        }

        auto const output_bus_count = this->output_bus_count();
        if (output_bus_count > 0) {
            auto each = make_fast_each(output_bus_count);
            while (yas_each_next(each)) {
                uint32_t const bus_idx = yas_each_index(each);

                AUAudioUnitBus *bus = raw_unit.object().outputBusses[bus_idx];
                bus.enabled = NO;

                if (auto connection = manageable_node::cast(this->_node)->output_connection(bus_idx)) {
                    NSError *error = nil;
                    auto const format = objc_ptr_with_move_object(
                        [[AVAudioFormat alloc] initWithStreamDescription:&connection->format.stream_description()]);
                    if ([bus setFormat:format.object() error:&error]) {
                        bus.enabled = YES;
                    } else {
                        auto component_name = to_string((__bridge CFStringRef)raw_unit.object().componentName);
                        auto error_message = to_string((__bridge CFStringRef)error.description);
                        std::cout << component_name << " bus_idx : " << bus_idx
                                  << " set output format - error : " << error_message << std::endl;
                    }
                }
            }
        }

        this->_connection_notifier->notify(connection_method::did_update);

        if (is_initialized) {
            this->_initialize_raw_unit();
        }
    }
}

void audio::engine::avf_au::_set_parameter_value(AudioUnitScope const scope, AudioUnitParameterID const parameter_id,
                                                 float const value, AudioUnitElement const element) {
    if (auto const raw_unit = this->_core->raw_unit()) {
        if (AUParameter *parameter =
                [raw_unit.value().object().parameterTree parameterWithID:parameter_id scope:scope element:0]) {
            parameter.value = value;
            return;
        }
    }
    std::cout << "avf_au _set_parameter_value failed." << std::endl;
}

float audio::engine::avf_au::_get_parameter_value(AudioUnitScope const scope, AudioUnitParameterID const parameter_id,
                                                  AudioUnitElement const element) const {
    if (auto const raw_unit = this->_core->raw_unit()) {
        if (AUParameter *parameter =
                [raw_unit.value().object().parameterTree parameterWithID:parameter_id scope:scope element:0]) {
            return parameter.value;
        }
    }
    std::cout << "avf_au _get_parameter_value failed." << std::endl;
    return 0.0f;
}

audio::engine::avf_au_ptr audio::engine::avf_au::make_shared(OSType const type, OSType const sub_type) {
    return avf_au::make_shared(AudioComponentDescription{
        .componentType = type,
        .componentSubType = sub_type,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    });
}

audio::engine::avf_au_ptr audio::engine::avf_au::make_shared(AudioComponentDescription const &acd) {
    return avf_au::make_shared({.acd = acd, .node_args = {.input_bus_count = 1, .output_bus_count = 1}});
}

audio::engine::avf_au_ptr audio::engine::avf_au::make_shared(avf_au::args &&args) {
    auto shared = avf_au_ptr(new avf_au{std::move(args.node_args)});
    shared->_prepare(shared, args.acd);
    return shared;
}

#pragma mark -

std::string yas::to_string(audio::engine::avf_au::load_state const &state) {
    switch (state) {
        case audio::engine::avf_au::load_state::unload:
            return "unload";
        case audio::engine::avf_au::load_state::loaded:
            return "loaded";
        case audio::engine::avf_au::load_state::failed:
            return "failed";
    }
}
