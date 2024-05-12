//
//  avf_au.mm
//

#import <AVFoundation/AVFoundation.h>
#include <audio-engine/avf_au/avf_au.h>
#include <audio-engine/avf_au/avf_au_parameter.h>
#include <audio-engine/common/time.h>
#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-engine/utils/debug.h>
#include <audio-engine/utils/objc_utils.h>
#include <cpp-utils/yas_cf_utils.h>
#include <cpp-utils/yas_exception.h>
#include <cpp-utils/yas_objc_ptr.h>
#include <cpp-utils/yas_stl_utils.h>
#include <cpp-utils/yas_thread.h>

using namespace yas;
using namespace yas::audio;

#pragma mark - avf_au_parameter_utils

namespace yas::audio::avf_au_parameter_utils {
std::vector<std::string> value_strings(AUParameter *const objc_param) {
    if (auto const valueStrings = objc_param.valueStrings) {
        std::vector<std::string> result;
        result.reserve(valueStrings.count);

        for (NSString *valueString in valueStrings) {
            result.emplace_back(to_string((__bridge CFStringRef)valueString));
        }

        return result;
    } else {
        return {};
    }
}

std::vector<float> values(AUParameter *const objc_param) {
    auto const strings = avf_au_parameter_utils::value_strings(objc_param);
    return yas::to_vector<float>(strings, [&objc_param](std::string const &string) {
        return [objc_param valueFromString:(__bridge NSString *)to_cf_object(string)];
    });
}

std::optional<std::string> unit_name(AUParameter *const objc_param) {
    if (NSString *unitName = objc_param.unitName) {
        return to_string((__bridge CFStringRef)unitName);
    } else {
        return std::nullopt;
    }
}
}  // namespace yas::audio::avf_au_parameter_utils

#pragma mark - avf_au::core

struct yas::audio::avf_au::core {
    struct render_context {
        std::vector<format> const output_formats;
        std::vector<format> const input_formats;

        render_context(std::vector<format> &&output_formats, std::vector<format> &&input_formats)
            : output_formats(std::move(output_formats)), input_formats(std::move(input_formats)) {
        }

        format const *output_format(uint32_t const idx) const {
            if (idx < this->output_formats.size()) {
                return &this->output_formats.at(idx);
            } else {
                return nullptr;
            }
        }

        format const *input_format(uint32_t const idx) const {
            if (idx < this->input_formats.size()) {
                return &this->input_formats.at(idx);
            } else {
                return nullptr;
            }
        }
    };

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
                                                   shared_au->_core->_raw_unit = objc_ptr<AUAudioUnit *>{audioUnit};
                                                   shared_au->_setup();
                                                   shared_au->_load_state->set_value(load_state::loaded);
                                               }
                                           }
                                       }];
    }

    bool is_initialized() {
        return this->_render_context != nullptr;
    }

    void initialize() {
        raise_if_sub_thread();

        if (this->is_initialized()) {
            return;
        }

        std::lock_guard<std::recursive_mutex> lock(this->_initialize_mutex);

        AUAudioUnit *const raw_unit = this->_raw_unit.object();

        NSError *error = nil;

        if ([raw_unit allocateRenderResourcesAndReturnError:&error]) {
            std::vector<format> output_formats;
            std::vector<format> input_formats;

            for (AUAudioUnitBus *bus in raw_unit.outputBusses) {
                output_formats.emplace_back(*bus.format.streamDescription);
            }

            for (AUAudioUnitBus *bus in raw_unit.inputBusses) {
                input_formats.emplace_back(*bus.format.streamDescription);
            }

            this->_render_context =
                std::make_shared<render_context>(std::move(output_formats), std::move(input_formats));
        } else {
            yas_audio_log(("initialize - error : " + to_string((__bridge CFStringRef)error.description)));
        }
    }

    void uninitialize() {
        raise_if_sub_thread();

        if (!this->is_initialized()) {
            return;
        }

        std::lock_guard<std::recursive_mutex> lock(this->_initialize_mutex);

        [this->_raw_unit.object() deallocateRenderResources];
        this->_render_context = nullptr;
    }

    objc_ptr<AUAudioUnit *> const &raw_unit() const {
        return this->_raw_unit;
    }

    void render(render_args const &args, input_render_f const &input_handler) {
        raise_if_main_thread();

        auto lock = std::unique_lock<std::recursive_mutex>(this->_initialize_mutex, std::try_to_lock);

        if (!lock.owns_lock()) {
            return;
        }

        auto const &render_context = this->_render_context;

        format const *const output_format = render_context->output_format(args.bus_idx);
        if (!output_format) {
            return;
        }

        if (*output_format != args.buffer->format()) {
            return;
        }

        AudioUnitRenderActionFlags action_flags = 0;
        AudioTimeStamp const time_stamp = args.time.audio_time_stamp();

        @autoreleasepool {
            this->_raw_unit.object().renderBlock(
                &action_flags, &time_stamp, args.buffer->frame_length(), args.bus_idx, args.buffer->audio_buffer_list(),
                [this, &input_handler, &render_context](AudioUnitRenderActionFlags *actionFlags,
                                                        const AudioTimeStamp *timestamp, AUAudioFrameCount frameCount,
                                                        NSInteger inputBusNumber, AudioBufferList *inputData) {
                    audio::clear(inputData);

                    format const *const input_format = render_context->input_format((uint32_t)inputBusNumber);
                    if (input_format) {
                        pcm_buffer buffer(*input_format, inputData);
                        buffer.set_frame_length(frameCount);

                        time time(*timestamp, input_format->sample_rate());

                        input_handler({.buffer = &buffer, .bus_idx = (uint32_t)inputBusNumber, .time = time});
                    }

                    return AUAudioUnitStatus(noErr);
                });
        }
    }

    avf_au_parameter_ptr make_parameter(AUParameter *const objc_param) {
        auto const parameter = avf_au_parameter::make_shared(
            to_string((__bridge CFStringRef)objc_param.keyPath), to_string((__bridge CFStringRef)objc_param.identifier),
            objc_param.unit, avf_au_parameter_utils::unit_name(objc_param), objc_param.value,
            to_string((__bridge CFStringRef)objc_param.displayName), objc_param.minValue, objc_param.maxValue,
            avf_au_parameter_utils::value_strings(objc_param), avf_au_parameter_utils::values(objc_param));

        parameter->set_value_changed_handler([this, key_path = parameter->key_path](float const value) {
            if (AUParameter *const objc_parameter = this->raw_parameter(key_path)) {
                objc_parameter.value = value;
            }
        });

        return parameter;
    }

    AUParameter *raw_parameter(std::string const &key_path) {
        for (AUParameter *objc_param in this->_raw_unit.object().parameterTree.allParameters) {
            if (key_path == to_string((__bridge CFStringRef)objc_param.keyPath)) {
                return objc_param;
            }
        }
        return nil;
    }

   private:
    objc_ptr<AUAudioUnit *> _raw_unit{nil};

    mutable std::recursive_mutex _initialize_mutex;
    std::shared_ptr<render_context> _render_context = nullptr;
};

#pragma mark - avf_au

avf_au::avf_au() : _core(std::make_unique<core>()) {
}

AudioComponentDescription avf_au::componentDescription() const {
    return this->_core->raw_unit().object().componentDescription;
}

void avf_au::set_input_bus_count(uint32_t const count) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto const &raw_unit = this->_core->raw_unit();
    AUAudioUnitBusArray *inputBusses = raw_unit.object().inputBusses;
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

void avf_au::set_output_bus_count(uint32_t const count) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto const &raw_unit = this->_core->raw_unit();
    AUAudioUnitBusArray *outputBusses = raw_unit.object().outputBusses;
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

uint32_t avf_au::input_bus_count() const {
    return (uint32_t)this->_core->raw_unit().object().inputBusses.count;
}

uint32_t avf_au::output_bus_count() const {
    return (uint32_t)this->_core->raw_unit().object().outputBusses.count;
}

void avf_au::set_input_format(format const &format, uint32_t const bus_idx) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto const &raw_unit = this->_core->raw_unit();

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

void avf_au::set_output_format(format const &format, uint32_t const bus_idx) {
    if (this->is_initialized()) {
        std::runtime_error("avf_au initialized.");
    }

    auto const &raw_unit = this->_core->raw_unit();

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

format avf_au::input_format(uint32_t const bus_idx) const {
    return format{*this->_core->raw_unit().object().inputBusses[bus_idx].format.streamDescription};
}

format avf_au::output_format(uint32_t const bus_idx) const {
    return format{*this->_core->raw_unit().object().outputBusses[bus_idx].format.streamDescription};
}

void avf_au::initialize() {
    this->_core->initialize();
}

void avf_au::uninitialize() {
    this->_core->uninitialize();
}

bool avf_au::is_initialized() const {
    return this->_core->is_initialized();
}

void avf_au::reset() {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        [raw_unit.object() reset];
    }

    for (auto const &parameters : {this->_global_parameters, this->_output_parameters, this->_input_parameters}) {
        for (auto const &parameter : parameters) {
            parameter->reset_value();
        }
    }
}

std::string avf_au::component_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.object().componentName);
    }
    return "";
}

std::string avf_au::audio_unit_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.object().audioUnitName);
    }
    return "";
}

std::string avf_au::audio_unit_short_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.object().audioUnitShortName);
    }
    return "";
}

std::string avf_au::manufacture_name() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return to_string((__bridge CFStringRef)raw_unit.object().manufacturerName);
    }
    return "";
}

uint32_t avf_au::component_version() const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        return raw_unit.object().componentVersion;
    }
    return 0;
}

void avf_au::set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value) {
    this->_set_parameter_value(avf_au_parameter_scope::global, parameter_id, value, 0);
}

float avf_au::global_parameter_value(AudioUnitParameterID const parameter_id) const {
    return this->_get_parameter_value(avf_au_parameter_scope::global, parameter_id, 0);
}

void avf_au::set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                       AudioUnitElement const element) {
    this->_set_parameter_value(avf_au_parameter_scope::input, parameter_id, value, element);
}

float avf_au::input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const {
    return this->_get_parameter_value(avf_au_parameter_scope::input, parameter_id, element);
}

void avf_au::set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                        AudioUnitElement const element) {
    this->_set_parameter_value(avf_au_parameter_scope::output, parameter_id, value, element);
}

float avf_au::output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const {
    return this->_get_parameter_value(avf_au_parameter_scope::output, parameter_id, element);
}

std::vector<avf_au_parameter_ptr> const &avf_au::global_parameters() const {
    return this->_global_parameters;
}

std::vector<avf_au_parameter_ptr> const &avf_au::input_parameters() const {
    return this->_input_parameters;
}

std::vector<avf_au_parameter_ptr> const &avf_au::output_parameters() const {
    return this->_output_parameters;
}

std::optional<avf_au_parameter_ptr> avf_au::parameter(AudioUnitParameterID const parameter_id,
                                                      avf_au_parameter_scope const scope,
                                                      AudioUnitElement element) const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        if (AUParameter *objc_param = [raw_unit.object().parameterTree parameterWithID:parameter_id
                                                                                 scope:to_raw_scope(scope)
                                                                               element:element]) {
            auto const key_path = to_string((__bridge CFStringRef)objc_param.keyPath);

            switch (scope) {
                case avf_au_parameter_scope::global: {
                    if (auto const parameter = first(this->_global_parameters, [&key_path](auto const &parameter) {
                            return parameter->key_path == key_path;
                        })) {
                        return parameter;
                    }
                } break;
                case avf_au_parameter_scope::output: {
                    if (auto const parameter = first(this->_output_parameters, [&key_path](auto const &parameter) {
                            return parameter->key_path == key_path;
                        })) {
                        return parameter;
                    }
                } break;
                case avf_au_parameter_scope::input: {
                    if (auto const parameter = first(this->_input_parameters, [&key_path](auto const &parameter) {
                            return parameter->key_path == key_path;
                        })) {
                        return parameter;
                    }
                } break;
            }
        }
    }

    return std::nullopt;
}

void avf_au::render(render_args const &args, input_render_f const &input_handler) {
    this->_core->render(args, input_handler);
}

avf_au::load_state avf_au::state() const {
    return this->_load_state->value();
}

observing::syncable avf_au::observe_load_state(observing::caller<load_state>::handler_f &&handler) {
    return this->_load_state->observe(std::move(handler));
}

audio::avf_au_ptr avf_au::make_shared(OSType const type, OSType const sub_type) {
    return avf_au::make_shared(AudioComponentDescription{
        .componentType = type,
        .componentSubType = sub_type,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0,
    });
}

void avf_au::_prepare(avf_au_ptr const &shared, AudioComponentDescription const &acd) {
    shared->_core->load_raw_unit(acd, shared);
}

void avf_au::_setup() {
    auto const &raw_unit = this->_core->raw_unit();

    raw_unit.object().maximumFramesToRender = 4096;

    this->_global_parameters.clear();
    this->_input_parameters.clear();
    this->_output_parameters.clear();

    for (AUParameter *objc_param in raw_unit.object().parameterTree.allParameters) {
        auto parameter = this->_core->make_parameter(objc_param);

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

void avf_au::_update_input_parameters() {
    auto const &raw_unit = this->_core->raw_unit();

    auto const prev_input_parameters = std::move(this->_input_parameters);
    this->_input_parameters.clear();

    for (AUParameter *objc_param in raw_unit.object().parameterTree.allParameters) {
        auto const key_path = to_string((__bridge CFStringRef)objc_param.keyPath);
        auto const scope = avf_au_parameter::scope_from_key_path(key_path);

        switch (scope) {
            case avf_au_parameter_scope::input: {
                if (auto const prev = first(prev_input_parameters, [&key_path](auto const &parameter) {
                        return parameter->key_path == key_path;
                    })) {
                    this->_input_parameters.emplace_back(prev.value());
                } else {
                    auto parameter = this->_core->make_parameter(objc_param);
                    this->_input_parameters.emplace_back(std::move(parameter));
                }
            } break;
            case avf_au_parameter_scope::global:
            case avf_au_parameter_scope::output:
                break;
        }
    }
}

void avf_au::_update_output_parameters() {
    auto const &raw_unit = this->_core->raw_unit();

    auto const prev_output_parameters = std::move(this->_output_parameters);
    this->_output_parameters.clear();

    for (AUParameter *objc_param in raw_unit.object().parameterTree.allParameters) {
        auto const key_path = to_string((__bridge CFStringRef)objc_param.keyPath);
        auto const scope = avf_au_parameter::scope_from_key_path(key_path);

        switch (scope) {
            case avf_au_parameter_scope::output: {
                if (auto const prev = first(prev_output_parameters, [&key_path](auto const &parameter) {
                        return parameter->key_path == key_path;
                    })) {
                    this->_output_parameters.emplace_back(prev.value());
                } else {
                    auto parameter = this->_core->make_parameter(objc_param);
                    this->_output_parameters.emplace_back(std::move(parameter));
                }
            } break;
            case avf_au_parameter_scope::global:
            case avf_au_parameter_scope::input:
                break;
        }
    }
}

void avf_au::_set_parameter_value(avf_au_parameter_scope const scope, AudioUnitParameterID const parameter_id,
                                  float const value, AudioUnitElement const element) {
    if (auto const parameter = this->parameter(parameter_id, scope, element)) {
        parameter.value()->set_value(value);
    } else {
        throw std::invalid_argument("_set_parameter_value - parameter not found. element (" + std::to_string(element) +
                                    ")");
    }
}

float avf_au::_get_parameter_value(avf_au_parameter_scope const scope, AudioUnitParameterID const parameter_id,
                                   AudioUnitElement const element) const {
    if (auto const &raw_unit = this->_core->raw_unit()) {
        if (AUParameter *objc_param = [raw_unit.object().parameterTree parameterWithID:parameter_id
                                                                                 scope:to_raw_scope(scope)
                                                                               element:element]) {
            return objc_param.value;
        }
    }
    yas_audio_log("avf_au _get_parameter_value failed.");
    return 0.0f;
}

audio::avf_au_ptr avf_au::make_shared(AudioComponentDescription const &acd) {
    auto shared = avf_au_ptr(new avf_au{});
    shared->_prepare(shared, acd);
    return shared;
}

#pragma mark -

std::string yas::to_string(avf_au::load_state const &state) {
    switch (state) {
        case avf_au::load_state::unload:
            return "unload";
        case avf_au::load_state::loaded:
            return "loaded";
        case avf_au::load_state::failed:
            return "failed";
    }
}
