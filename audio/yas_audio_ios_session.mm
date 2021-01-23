//
//  yas_audio_ios_session.mm
//

#include "yas_audio_ios_session.h"

#if TARGET_OS_IPHONE

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <cpp_utils/yas_cf_utils.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <vector>
#include "yas_audio_debug.h"

using namespace yas;
using namespace yas::audio;

static AVAudioSessionCategory to_objc(enum ios_session::category const category) {
    switch (category) {
        case ios_session::category::ambient:
            return AVAudioSessionCategoryAmbient;
        case ios_session::category::solo_ambient:
            return AVAudioSessionCategorySoloAmbient;
        case ios_session::category::playback:
            return AVAudioSessionCategoryPlayback;
        case ios_session::category::record:
            return AVAudioSessionCategoryRecord;
        case ios_session::category::play_and_record:
            return AVAudioSessionCategoryPlayAndRecord;
        case ios_session::category::multi_route:
            return AVAudioSessionCategoryMultiRoute;
    }
}

static AVAudioSessionCategoryOptions to_objc(ios_session::category_options_t const options) {
    AVAudioSessionCategoryOptions result = kNilOptions;

    if (options.test(ios_session::category_option::mix_with_others)) {
        result |= AVAudioSessionCategoryOptionMixWithOthers;
    }

    if (options.test(ios_session::category_option::duck_others)) {
        result |= AVAudioSessionCategoryOptionDuckOthers;
    }

    if (options.test(ios_session::category_option::allow_bluetooth)) {
        result |= AVAudioSessionCategoryOptionAllowBluetooth;
    }

    if (options.test(ios_session::category_option::default_to_speaker)) {
        result |= AVAudioSessionCategoryOptionDefaultToSpeaker;
    }

    if (options.test(ios_session::category_option::interrupt_spoken_audio_and_mix_with_others)) {
        result |= AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers;
    }

    if (options.test(ios_session::category_option::allow_bluetooth_a2dp)) {
        result |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
    }

    if (options.test(ios_session::category_option::allow_air_play)) {
        result |= AVAudioSessionCategoryOptionAllowAirPlay;
    }

    return result;
}

struct ios_session::impl {
    std::vector<objc_ptr<id<NSObject>>> observers;

    std::optional<objc_ptr<>> did_become_active_observer = std::nullopt;
    std::optional<objc_ptr<>> interruption_observer = std::nullopt;

    ~impl() {
        for (auto const &observer : this->observers) {
            [NSNotificationCenter.defaultCenter removeObserver:observer.object()];
        }
    }
};

ios_session::ios_session()
    : _category(category::playback),
      _impl(std::make_unique<impl>()),
      _device_notifier(observing::notifier<device_method>::make_shared()),
      _interruption_notifier(observing::notifier<interruption_method>::make_shared()) {
    auto route_change_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioSessionRouteChangeNotification
                        object:AVAudioSession.sharedInstance
                         queue:NSOperationQueue.mainQueue
                    usingBlock:[this](NSNotification *note) {
                        if (this->_is_active) {
                            yas_audio_log(("ios_session route_change notification - sample_rate : " +
                                           std::to_string(this->sample_rate()) +
                                           " output_channel_count : " + std::to_string(this->output_channel_count()) +
                                           " input_channel_count : " + std::to_string(this->input_channel_count())));
                            this->_device_notifier->notify(device_method::route_change);
                        }
                    }];
    });

    auto lost_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioSessionMediaServicesWereLostNotification
                        object:AVAudioSession.sharedInstance
                         queue:NSOperationQueue.mainQueue
                    usingBlock:[this](NSNotification *note) {
                        if (this->_is_active) {
                            yas_audio_log("ios_session lost notification");
                            this->_device_notifier->notify(device_method::media_service_were_lost);
                        }
                    }];
    });

    auto reset_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                        object:AVAudioSession.sharedInstance
                         queue:NSOperationQueue.mainQueue
                    usingBlock:[this](NSNotification *note) {
                        if (this->_is_active) {
                            yas_audio_log("ios_session reset notification");
                            this->_device_notifier->notify(device_method::media_service_were_reset);
                        }
                    }];
    });

    this->_impl->observers = {route_change_observer, lost_observer, reset_observer};
}

bool ios_session::is_active() const {
    return this->_is_active;
}

ios_session::activate_result_t ios_session::activate() {
    if (auto result = this->_apply_category(); !result) {
        return result;
    }

    if (auto result = this->_apply_sample_rate(); !result) {
        return result;
    }

    if (auto result = this->_set_active(); !result) {
        return result;
    }

    if (!this->_is_active) {
        this->_is_active = true;

        this->_setup_interrupting();

        this->_device_notifier->notify(device_method::activate);
    }

    if (auto result = this->_apply_io_buffer_duration(); !result) {
        return result;
    }

    yas_audio_log("ios session activated.");

    return activate_result_t{nullptr};
}

ios_session::activate_result_t ios_session::reactivate() {
    if (!this->_is_active) {
        return activate_result_t{nullptr};
    }

    if (auto result = this->_apply_category(); !result) {
        return result;
    }

    if (auto result = this->_apply_sample_rate(); !result) {
        return result;
    }

    if (auto result = this->_set_active(); !result) {
        return result;
    }

    if (auto result = this->_apply_io_buffer_duration(); !result) {
        return result;
    }

    return activate_result_t{nullptr};
}

void ios_session::deactivate() {
    this->_dispose_interrupting();

    NSError *error = nil;
    if ([[AVAudioSession sharedInstance] setActive:NO error:&error]) {
        yas_audio_log("ios session deactivated.");
        this->_is_active = false;
        this->_device_notifier->notify(device_method::deactivate);
    } else {
        yas_audio_log(
            ("ios session deactivate error : " + to_string((__bridge CFStringRef)(error.description ?: @""))));
    }
}

bool ios_session::is_interrupting() const {
    return this->_is_interrupting;
}

double ios_session::sample_rate() const {
    if (!this->_is_active) {
        return 0.0;
    }

    return [AVAudioSession sharedInstance].sampleRate;
}

void ios_session::set_preferred_sample_rate(double const sample_rate) {
    this->_preferred_sample_rate = sample_rate;

    if (this->_is_active) {
        this->_apply_sample_rate();
    }
}

void ios_session::set_preferred_io_buffer_frames(uint32_t const frames) {
    this->_preferred_io_buffer_frames = frames;

    if (this->_is_active) {
        this->_apply_io_buffer_duration();
    }
}

uint32_t ios_session::output_channel_count() const {
    if (!this->_is_active) {
        return 0;
    }

    if (is_output_category(this->_category)) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
    } else {
        return 0;
    }
}

uint32_t ios_session::input_channel_count() const {
    if (!this->_is_active) {
        return 0;
    }

    if (this->is_input_available() && is_input_category(this->_category)) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
    } else {
        return 0;
    }
}

bool ios_session::is_input_available() const {
    if (!this->_is_active) {
        return false;
    }

    return [AVAudioSession sharedInstance].isInputAvailable;
}

enum ios_session::category ios_session::category() const {
    return this->_category;
}

void ios_session::set_category(enum category const category) {
    this->set_category(category, {});
}

void ios_session::set_category(enum category const category, category_options_t const options) {
    this->_category = category;
    this->_category_options = options;

    if (this->_is_active) {
        this->_apply_category();
    }
}

observing::canceller_ptr ios_session::observe_device(observing::caller<device_method>::handler_f &&handler) {
    return this->_device_notifier->observe(std::move(handler));
}

observing::canceller_ptr ios_session::observe_interruption(
    observing::caller<interruption_method>::handler_f &&handler) {
    return this->_interruption_notifier->observe(std::move(handler));
}

ios_session::activate_result_t ios_session::_apply_category() {
    NSError *error = nil;

    if ([[AVAudioSession sharedInstance] setCategory:to_objc(this->_category)
                                         withOptions:to_objc(this->_category_options)
                                               error:&error]) {
        return activate_result_t{nullptr};
    } else {
        auto const error_description = to_string((__bridge CFStringRef)(error.description ?: @""));
        yas_audio_log(("ios session set category error : " + error_description));
        return activate_result_t{error_description};
    }
}

ios_session::activate_result_t ios_session::_apply_sample_rate() {
    NSError *error = nil;

    if ([[AVAudioSession sharedInstance] setPreferredSampleRate:this->_preferred_sample_rate error:&error]) {
        return activate_result_t{nullptr};
    } else {
        auto const error_description = to_string((__bridge CFStringRef)(error.description ?: @""));
        yas_audio_log(("ios session set sample rate error : " + error_description));
        return activate_result_t{error_description};
    }
}

ios_session::activate_result_t ios_session::_apply_io_buffer_duration() {
    if (!this->_is_active) {
        throw std::runtime_error("audio session is not activate.");
    }

    double const sample_rate = this->sample_rate();

    if (sample_rate == 0) {
        return activate_result_t{"sample rate is zero."};
    }

    NSError *error = nil;

    double const duration = this->_preferred_io_buffer_frames / sample_rate;

    if ([[AVAudioSession sharedInstance] setPreferredIOBufferDuration:duration error:&error]) {
        return activate_result_t{nullptr};
    } else {
        auto const error_description = to_string((__bridge CFStringRef)(error.description ?: @""));
        yas_audio_log(("ios session set io buffer duration error : " + error_description));
        return activate_result_t{error_description};
    }
}

ios_session::activate_result_t ios_session::_set_active() {
    NSError *error = nil;

    if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        return activate_result_t{nullptr};
    } else {
        auto const error_description = to_string((__bridge CFStringRef)(error.description ?: @""));
        yas_audio_log(("ios session set active error : " + error_description));
        return activate_result_t{error_description};
    }
}

void ios_session::_set_interrupting_and_notify(bool const is_interrupting) {
    if (this->_is_interrupting != is_interrupting) {
        this->_is_interrupting = is_interrupting;
        this->_interruption_notifier->notify(is_interrupting ? interruption_method::began : interruption_method::ended);
    }
}

void ios_session::_setup_interrupting() {
    this->_is_interrupting = false;

    if (!this->_impl->did_become_active_observer) {
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:[this](NSNotification *note) {
                                                                        this->_set_active();
                                                                        this->_set_interrupting_and_notify(false);
                                                                    }];
        this->_impl->did_become_active_observer = objc_ptr<>(observer);
    }

    if (!this->_impl->interruption_observer) {
        auto const lambda = [this](NSNotification *note) {
            auto const type = AVAudioSessionInterruptionType(
                [[note.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]);

            switch (type) {
                case AVAudioSessionInterruptionTypeBegan:
                    this->_set_interrupting_and_notify(true);
                    break;
                case AVAudioSessionInterruptionTypeEnded:
                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                        auto const options = AVAudioSessionInterruptionOptions(
                            [[note.userInfo valueForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue]);
                        if (options & AVAudioSessionInterruptionOptionShouldResume) {
                            this->_set_active();
                            this->_set_interrupting_and_notify(false);
                        }
                    }
                    break;
            }
        };
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:std::move(lambda)];
        this->_impl->interruption_observer = objc_ptr<>(observer);
    }
}

void ios_session::_dispose_interrupting() {
    this->_is_interrupting = false;
    this->_impl->did_become_active_observer = std::nullopt;
    this->_impl->interruption_observer = std::nullopt;
}

ios_session_ptr const &ios_session::shared() {
    static ios_session_ptr const shared = ios_session_ptr(new ios_session{});
    return shared;
}

bool audio::is_output_category(enum ios_session::category const category) {
    switch (category) {
        case ios_session::category::ambient:
        case ios_session::category::solo_ambient:
        case ios_session::category::playback:
        case ios_session::category::play_and_record:
        case ios_session::category::multi_route:
            return true;
        case ios_session::category::record:
            return false;
    }
}

bool audio::is_input_category(enum ios_session::category const category) {
    switch (category) {
        case ios_session::category::play_and_record:
        case ios_session::category::record:
        case ios_session::category::multi_route:
            return true;
        case ios_session::category::ambient:
        case ios_session::category::solo_ambient:
        case ios_session::category::playback:
            return false;
    }
}

#endif
