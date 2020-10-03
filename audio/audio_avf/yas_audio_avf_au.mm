//
//  yas_audio_avf_au.mm
//

#include "yas_audio_avf_au.h"
#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_exception.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_stl_utils.h>
#include <cpp_utils/yas_thread.h>
#include "yas_audio_avf_au_parameter.h"
#include "yas_audio_avf_au_parameter_core.h"
#include "yas_audio_debug.h"
#include "yas_audio_objc_utils.h"
#include "yas_audio_pcm_buffer.h"
#include "yas_audio_time.h"

using namespace yas;

namespace yas::audio {
namespace avf_au_utils {
    AUParameter *objc_parameter(objc_ptr<AUAudioUnit *> const &raw_unit, audio::avf_au_parameter_scope const scope,
                                std::string const &identifier) {
        for (AUParameter *auParameter in raw_unit.object().parameterTree.allParameters) {
            auto core = avf_au_parameter_core::make_shared(auParameter);
            auto const parameter = avf_au_parameter::make_shared(core);

            if (scope == parameter->scope() && identifier == parameter->identifier()) {
                return auParameter;
            }
        }
        return nil;
    }
}

struct avf_au::core {
    void load_raw_unit(AudioComponentDescription const &acd, avf_au_ptr const &shared) {
        auto weak_au = to_weak(shared);

        [AUAudioUnit instantiateWithComponentDescription:acd
                                                 options:kAudioComponentInstantiation_LoadOutOfProcess
                                       completionHandler:^(AUAudioUnit *_Nullable audioUnit, NSError *_Nullable error) {
                                           raise_if_sub_thread();

                                           if (auto const shared_au = weak_au.lock()) {
                                               if (error) {
                                                   yas_audio_log(("load raw unit error : " +
                                                                  to_string((__bridge CFStringRef)error.description)));
                                                   shared_au->_load_state->set_value(load_state::failed);
                                               } else {
                                                   shared_au->_core->_set_raw_unit(objc_ptr<AUAudioUnit *>{audioUnit});
                                                   shared_au->_setup();
                                                   shared_au->_load_state->set_value(load_state::loaded);
                                               }
                                           }
                                       }];
    }

    bool is_initialized() {
        return this->_is_initialized;
    }

    void initialize() {
        raise_if_sub_thread();

        if (this->_is_initialized) {
            return;
        }

        std::lock_guard<std::recursive_mutex> lock(this->_initialize_mutex);

        auto const raw_unit = this->raw_unit().value();

        NSError *error = nil;

        if ([raw_unit.object() allocateRenderResourcesAndReturnError:&error]) {
            for (AUAudioUnitBus *bus in raw_unit.object().outputBusses) {
                this->_output_formats.emplace_back(*bus.format.streamDescription);
            }
            for (AUAudioUnitBus *bus in raw_unit.object().inputBusses) {
                this->_input_formats.emplace_back(*bus.format.streamDescription);
            }

            this->_is_initialized = true;
        } else {
            yas_audio_log(("initialize - error : " + to_string((__bridge CFStringRef)error.description)));
        }
    }

    void uninitialize() {
        raise_if_sub_thread();

        if (!this->_is_initialized) {
            return;
        }

        std::lock_guard<std::recursive_mutex> lock(this->_initialize_mutex);

        [this->raw_unit().value().object() deallocateRenderResources];

        this->_output_formats.clear();
        this->_input_formats.clear();

        this->_is_initialized = false;
    }

    std::optional<objc_ptr<AUAudioUnit *>> raw_unit() const {
        return this->_raw_unit;
    }

    void render(render_args const &args, input_render_f const &input_handler) {
        raise_if_main_thread();

        auto lock = std::unique_lock<std::recursive_mutex>(this->_initialize_mutex, std::try_to_lock);

        if (!lock.owns_lock()) {
            return;
        }

        auto output_format_opt = this->_output_format_on_render(args.bus_idx);
        if (!output_format_opt) {
            return;
        }

        auto const &output_format = output_format_opt.value();
        if (output_format != args.buffer->format()) {
            return;
        }

        AudioUnitRenderActionFlags action_flags = 0;
        AudioTimeStamp const time_stamp = args.time.audio_time_stamp();

        this->raw_unit().value().object().renderBlock(
            &action_flags, &time_stamp, args.buffer->frame_length(), args.bus_idx, args.buffer->audio_buffer_list(),
            [this, &input_handler](AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp,
                                   AUAudioFrameCount frameCount, NSInteger inputBusNumber, AudioBufferList *inputData) {
                audio::clear(inputData);

                auto input_format_opt = this->_input_format_on_render((uint32_t)inputBusNumber);
                if (input_format_opt) {
                    auto const &input_format = input_format_opt.value();

                    pcm_buffer buffer(input_format, inputData);
                    buffer.set_frame_length(frameCount);

                    audio::time time(*timestamp, input_format.sample_rate());

                    input_handler({.buffer = &buffer, .bus_idx = (uint32_t)inputBusNumber, .time = time});
                }

                return AUAudioUnitStatus(noErr);
            });
    }

   private:
    std::optional<objc_ptr<AUAudioUnit *>> _raw_unit = std::nullopt;

    mutable std::recursive_mutex _initialize_mutex;
    bool _is_initialized = false;
    std::vector<audio::format> _output_formats;
    std::vector<audio::format> _input_formats;

    void _set_raw_unit(objc_ptr<AUAudioUnit *> &&raw_unit) {
        this->_raw_unit = std::move(raw_unit);
    }

    std::optional<audio::format> _output_format_on_render(uint32_t const idx) {
        raise_if_main_thread();

        if (idx < this->_output_formats.size()) {
            return this->_output_formats.at(idx);
        } else {
            return std::nullopt;
        }
    }

    std::optional<audio::format> _input_format_on_render(uint32_t const idx) {
        raise_if_main_thread();

        if (idx < this->_input_formats.size()) {
            return this->_input_formats.at(idx);
        } else {
            return std::nullopt;
        }
    }
};
}

audio::avf_au::avf_au() : _core(std::make_unique<core>()) {
}

AudioComponentDescription audio::avf_au::componentDescription() const {
    return this->_core->raw_unit().value().object().componentDescription;
}

void audio::avf_au::set_input_bus_count(uint32_t const count) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto const raw_unit = this->_core->raw_unit();
    AUAudioUnitBusArray *inputBusses = raw_unit.value().object().inputBusses;
    if (inputBusses.isCountChangeable) {
        NSError *error = nil;
        if ([inputBusses setBusCount:count error:&error]) {
            this->_update_input_parameters();
        } else {
            yas_audio_log(("set input element count error : " + to_string((__bridge CFStringRef)error.description)));
        }
    } else {
        yas_audio_log("input element count is not changable.");
    }
}

void audio::avf_au::set_output_bus_count(uint32_t const count) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto const raw_unit = this->_core->raw_unit();
    AUAudioUnitBusArray *outputBusses = raw_unit.value().object().outputBusses;
    if (outputBusses.isCountChangeable) {
        NSError *error = nil;
        if ([outputBusses setBusCount:count error:&error]) {
            this->_update_output_parameters();
        } else {
            yas_audio_log(("set output element count error : " + to_string((__bridge CFStringRef)error.description)));
        }
    } else {
        yas_audio_log("output element count is not changable.");
    }
}

uint32_t audio::avf_au::input_bus_count() const {
    auto const raw_unit = this->_core->raw_unit();
    return (uint32_t)raw_unit.value().object().inputBusses.count;
}

uint32_t audio::avf_au::output_bus_count() const {
    auto const raw_unit = this->_core->raw_unit();
    return (uint32_t)raw_unit.value().object().outputBusses.count;
}

void audio::avf_au::set_input_format(audio::format const &format, uint32_t const bus_idx) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto raw_unit = this->_core->raw_unit().value();

    AUAudioUnitBus *bus = raw_unit.object().inputBusses[bus_idx];
    bus.enabled = NO;

    NSError *error = nil;

    auto const objc_format = to_objc_object(format);

    if ([bus setFormat:objc_format.object() error:&error]) {
        bus.enabled = YES;
    } else {
        auto component_name = to_string((__bridge CFStringRef)raw_unit.object().componentName);
        auto error_message = to_string((__bridge CFStringRef)error.description);
        auto const message =
            component_name + " bus_idx : " + std::to_string(bus_idx) + " set input format - error : " + error_message;
        throw std::runtime_error(message);
    }
}

void audio::avf_au::set_output_format(audio::format const &format, uint32_t const bus_idx) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto raw_unit = this->_core->raw_unit().value();

    AUAudioUnitBus *bus = raw_unit.object().outputBusses[bus_idx];
    bus.enabled = NO;

    NSError *error = nil;

    auto const objc_format = to_objc_object(format);

    if ([bus setFormat:objc_format.object() error:&error]) {
        bus.enabled = YES;
    } else {
        auto component_name = to_string((__bridge CFStringRef)raw_unit.object().componentName);
        auto error_message = to_string((__bridge CFStringRef)error.description);
        auto const message =
            component_name + " bus_idx : " + std::to_string(bus_idx) + " set output format - error : " + error_message;
        throw std::runtime_error(message);
    }
}

audio::format audio::avf_au::input_format(uint32_t const bus_idx) const {
    auto const raw_unit = this->_core->raw_unit().value();
    return audio::format{*raw_unit.object().inputBusses[bus_idx].format.streamDescription};
}

audio::format audio::avf_au::output_format(uint32_t const bus_idx) const {
    auto const raw_unit = this->_core->raw_unit().value();
    return audio::format{*raw_unit.object().outputBusses[bus_idx].format.streamDescription};
}

void audio::avf_au::initialize() {
    this->_core->initialize();
}

void audio::avf_au::uninitialize() {
    this->_core->uninitialize();
}

bool audio::avf_au::is_initialized() const {
    return this->_core->is_initialized();
}

void audio::avf_au::reset() {
    if (auto const raw_unit = this->_core->raw_unit()) {
        [raw_unit.value().object() reset];
    }

    for (auto const &parameters : {this->_global_parameters, this->_output_parameters, this->_input_parameters}) {
        for (auto const &parameter : parameters) {
            parameter->reset_value();
        }
    }
}

std::string audio::avf_au::component_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.value().object().componentName);
    }
    return "";
}

std::string audio::avf_au::audio_unit_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.value().object().audioUnitName);
    }
    return "";
}

std::string audio::avf_au::audio_unit_short_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.value().object().audioUnitShortName);
    }
    return "";
}

std::string audio::avf_au::manufacture_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.value().object().manufacturerName);
    }
    return "";
}

uint32_t audio::avf_au::component_version() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return raw_unit.value().object().componentVersion;
    }
    return 0;
}

void audio::avf_au::set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
    this->_set_parameter_value(avf_au_parameter_scope::global, parameter_id, value, 0);
}

float audio::avf_au::global_parameter_value(AudioUnitParameterID const parameter_id) const {
    return this->_get_parameter_value(avf_au_parameter_scope::global, parameter_id, 0);
}

void audio::avf_au::set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                              AudioUnitElement const element) {
    this->_set_parameter_value(avf_au_parameter_scope::input, parameter_id, value, element);
}

float audio::avf_au::input_parameter_value(AudioUnitParameterID const parameter_id,
                                           AudioUnitElement const element) const {
    return this->_get_parameter_value(avf_au_parameter_scope::input, parameter_id, element);
}

void audio::avf_au::set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                               AudioUnitElement const element) {
    this->_set_parameter_value(avf_au_parameter_scope::output, parameter_id, value, element);
}

float audio::avf_au::output_parameter_value(AudioUnitParameterID const parameter_id,
                                            AudioUnitElement const element) const {
    return this->_get_parameter_value(avf_au_parameter_scope::output, parameter_id, element);
}

std::vector<audio::avf_au_parameter_ptr> const &audio::avf_au::global_parameters() const {
    return this->_global_parameters;
}

std::vector<audio::avf_au_parameter_ptr> const &audio::avf_au::input_parameters() const {
    return this->_input_parameters;
}

std::vector<audio::avf_au_parameter_ptr> const &audio::avf_au::output_parameters() const {
    return this->_output_parameters;
}

std::optional<audio::avf_au_parameter_ptr> audio::avf_au::parameter(AudioUnitParameterID const parameter_id,
                                                                    avf_au_parameter_scope const scope,
                                                                    AudioUnitElement element) const {
    if (auto const raw_unit = this->_core->raw_unit()) {
        if (AUParameter *parameter = [raw_unit.value().object().parameterTree parameterWithID:parameter_id
                                                                                        scope:to_raw_scope(scope)
                                                                                      element:element]) {
            auto const identifier = to_string((__bridge CFStringRef)parameter.identifier);

            switch (scope) {
                case avf_au_parameter_scope::global: {
                    if (auto const parameter = first(this->_global_parameters, [identifier](auto const &parameter) {
                            return parameter->identifier() == identifier;
                        })) {
                        return parameter;
                    }
                } break;
                case avf_au_parameter_scope::output: {
                    if (auto const parameter = first(this->_output_parameters, [identifier](auto const &parameter) {
                            return parameter->identifier() == identifier;
                        })) {
                        return parameter;
                    }
                } break;
                case avf_au_parameter_scope::input: {
                    if (auto const parameter = first(this->_input_parameters, [identifier](auto const &parameter) {
                            return parameter->identifier() == identifier;
                        })) {
                        return parameter;
                    }
                } break;
            }
        }
    }

    return std::nullopt;
}

void audio::avf_au::render(render_args const &args, input_render_f const &input_handler) {
    this->_core->render(args, input_handler);
}

audio::avf_au::load_state audio::avf_au::state() const {
    return this->_load_state->raw();
}

chaining::chain_sync_t<audio::avf_au::load_state> audio::avf_au::load_state_chain() const {
    return this->_load_state->chain();
}

audio::avf_au_ptr audio::avf_au::make_shared(OSType const type, OSType const sub_type) {
    return avf_au::make_shared(AudioComponentDescription{
        .componentType = type,
        .componentSubType = sub_type,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    });
}

void audio::avf_au::_prepare(avf_au_ptr const &shared, AudioComponentDescription const &acd) {
    shared->_core->load_raw_unit(acd, shared);
}

void audio::avf_au::_setup() {
    auto const raw_unit = this->_core->raw_unit();

    raw_unit.value().object().maximumFramesToRender = 4096;

    this->_global_parameters.clear();
    this->_input_parameters.clear();
    this->_output_parameters.clear();

    for (AUParameter *auParameter in raw_unit.value().object().parameterTree.allParameters) {
        auto parameter = this->_make_parameter(avf_au_parameter_core::make_shared(auParameter));

        switch (parameter->scope()) {
            case avf_au_parameter_scope::global:
                this->_global_parameters.emplace_back(std::move(parameter));
                break;
            case avf_au_parameter_scope::input:
                this->_input_parameters.emplace_back(std::move(parameter));
                break;
            case avf_au_parameter_scope::output:
                this->_output_parameters.emplace_back(std::move(parameter));
                break;
        }
    }
}

audio::avf_au_parameter_ptr audio::avf_au::_make_parameter(avf_au_parameter_core_ptr &&core) {
    auto const parameter = avf_au_parameter::make_shared(core);
    auto const scope = parameter->scope();

    parameter->set_value_changed_handler([this, scope, identifier = parameter->identifier()](float const value) {
        if (auto *const objc_parameter =
                avf_au_utils::objc_parameter(this->_core->raw_unit().value(), scope, identifier)) {
            objc_parameter.value = value;
        }
    });

    return parameter;
}

void audio::avf_au::_update_input_parameters() {
    auto const raw_unit = this->_core->raw_unit();

    auto const prev_input_parameters = std::move(this->_input_parameters);
    this->_input_parameters.clear();

    for (AUParameter *auParameter in raw_unit.value().object().parameterTree.allParameters) {
        auto const key_path = to_string((__bridge CFStringRef)auParameter.keyPath);
        auto const scope = avf_au_parameter::scope_from_key_path(key_path);

        switch (scope) {
            case avf_au_parameter_scope::input: {
                auto const identifier = to_string((__bridge CFStringRef)auParameter.identifier);
                if (auto const prev = first(prev_input_parameters, [&identifier](auto const &parameter) {
                        return parameter->identifier() == identifier;
                    })) {
                    this->_input_parameters.emplace_back(prev.value());
                } else {
                    auto parameter = this->_make_parameter(avf_au_parameter_core::make_shared(auParameter));
                    this->_input_parameters.emplace_back(parameter);
                }
            } break;
            case avf_au_parameter_scope::global:
            case avf_au_parameter_scope::output:
                break;
        }
    }
}

void audio::avf_au::_update_output_parameters() {
    auto const raw_unit = this->_core->raw_unit();

    auto const prev_output_parameters = std::move(this->_output_parameters);
    this->_output_parameters.clear();

    for (AUParameter *auParameter in raw_unit.value().object().parameterTree.allParameters) {
        auto const key_path = to_string((__bridge CFStringRef)auParameter.keyPath);
        auto const scope = avf_au_parameter::scope_from_key_path(key_path);

        switch (scope) {
            case avf_au_parameter_scope::output: {
                auto const identifier = to_string((__bridge CFStringRef)auParameter.identifier);
                if (auto const prev = first(prev_output_parameters, [&identifier](auto const &parameter) {
                        return parameter->identifier() == identifier;
                    })) {
                    this->_output_parameters.emplace_back(prev.value());
                } else {
                    auto parameter = this->_make_parameter(avf_au_parameter_core::make_shared(auParameter));
                    this->_output_parameters.emplace_back(parameter);
                }
            } break;
            case avf_au_parameter_scope::global:
            case avf_au_parameter_scope::input:
                break;
        }
    }
}

void audio::avf_au::_set_parameter_value(avf_au_parameter_scope const scope, AudioUnitParameterID const parameter_id,
                                         float const value, AudioUnitElement const element) {
    if (auto const parameter = this->parameter(parameter_id, scope, element)) {
        parameter.value()->set_value(value);
    } else {
        throw std::invalid_argument("_set_parameter_value - parameter not found. element (" + std::to_string(element) +
                                    ")");
    }
}

float audio::avf_au::_get_parameter_value(avf_au_parameter_scope const scope, AudioUnitParameterID const parameter_id,
                                          AudioUnitElement const element) const {
    if (auto const raw_unit = this->_core->raw_unit()) {
        if (AUParameter *parameter = [raw_unit.value().object().parameterTree parameterWithID:parameter_id
                                                                                        scope:to_raw_scope(scope)
                                                                                      element:element]) {
            return parameter.value;
        }
    }
    yas_audio_log("avf_au _get_parameter_value failed.");
    return 0.0f;
}

audio::avf_au_ptr audio::avf_au::make_shared(AudioComponentDescription const &acd) {
    auto shared = avf_au_ptr(new avf_au{});
    shared->_prepare(shared, acd);
    return shared;
}

#pragma mark -

std::string yas::to_string(audio::avf_au::load_state const &state) {
    switch (state) {
        case audio::avf_au::load_state::unload:
            return "unload";
        case audio::avf_au::load_state::loaded:
            return "loaded";
        case audio::avf_au::load_state::failed:
            return "failed";
    }
}
