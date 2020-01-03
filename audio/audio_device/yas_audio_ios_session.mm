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

using namespace yas;

static AVAudioSessionCategory to_objc_category(enum audio::ios_session::category category) {
    switch (category) {
        case audio::ios_session::category::ambient:
            return AVAudioSessionCategoryAmbient;
        case audio::ios_session::category::solo_ambient:
            return AVAudioSessionCategorySoloAmbient;
        case audio::ios_session::category::playback:
            return AVAudioSessionCategoryPlayback;
        case audio::ios_session::category::record:
            return AVAudioSessionCategoryRecord;
        case audio::ios_session::category::play_and_record:
            return AVAudioSessionCategoryPlayAndRecord;
        case audio::ios_session::category::multi_route:
            return AVAudioSessionCategoryMultiRoute;
    }
}

struct audio::ios_session::impl {
    std::vector<objc_ptr<id<NSObject>>> observers;

    std::optional<objc_ptr<>> did_become_active_observer = std::nullopt;
    std::optional<objc_ptr<>> interruption_observer = std::nullopt;

    ~impl() {
        for (auto const &observer : this->observers) {
            [NSNotificationCenter.defaultCenter removeObserver:observer.object()];
        }
    }
};

audio::ios_session::ios_session()
    : _category(category::playback),
      _impl(std::make_unique<impl>()),
      _device_notifier(chaining::notifier<device_method>::make_shared()),
      _interruption_notifier(chaining::notifier<interruption_method>::make_shared()) {
    auto route_change_observer = objc_ptr<id<NSObject>>([this] {
        return
            [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification
                                                            object:AVAudioSession.sharedInstance
                                                             queue:NSOperationQueue.mainQueue
                                                        usingBlock:[this](NSNotification *note) {
                                                            this->_device_notifier->notify(device_method::route_change);
                                                        }];
    });

    auto lost_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioSessionMediaServicesWereLostNotification
                        object:AVAudioSession.sharedInstance
                         queue:NSOperationQueue.mainQueue
                    usingBlock:[this](NSNotification *note) {
                        this->_device_notifier->notify(device_method::media_service_were_lost);
                    }];
    });

    auto reset_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                        object:AVAudioSession.sharedInstance
                         queue:NSOperationQueue.mainQueue
                    usingBlock:[this](NSNotification *note) {
                        this->_device_notifier->notify(device_method::media_service_were_reset);
                    }];
    });

    this->_impl->observers = {route_change_observer, lost_observer, reset_observer};
}

bool audio::ios_session::is_active() const {
    return this->_is_active;
}

audio::ios_session::activate_result_t audio::ios_session::activate() {
    if (auto result = this->_set_category(); !result) {
        return result;
    }

    if (auto result = this->_set_sample_rate(); !result) {
        return result;
    }

    if (auto result = this->_set_io_buffer_duration(); !result) {
        return result;
    }

    if (auto result = this->_set_active(); !result) {
        return result;
    }

    this->_setup_interrupting();
    this->_is_active = true;

    return activate_result_t{nullptr};
}

void audio::ios_session::deactivate() {
    this->_dispose_interrupting();

    NSError *error = nil;
    if ([[AVAudioSession sharedInstance] setActive:NO error:&error]) {
        this->_is_active = false;
    } else {
        NSLog(@"ios session deactivate error : %@", error);
    }
}

bool audio::ios_session::is_interrupting() const {
    return this->_is_interrupting;
}

double audio::ios_session::sample_rate() const {
    if (!this->_is_active) {
        throw std::runtime_error("audio session is not activate.");
    }

    return [AVAudioSession sharedInstance].sampleRate;
}

void audio::ios_session::set_preferred_sample_rate(double const sample_rate) {
    this->_preferred_sample_rate = sample_rate;
}

void audio::ios_session::set_preferred_io_buffer_frames(uint32_t const frames) {
    this->_preferred_io_buffer_frames = frames;
}

uint32_t audio::ios_session::output_channel_count() const {
    if (!this->_is_active) {
        throw std::runtime_error("audio session is not activate.");
    }

    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
}

uint32_t audio::ios_session::input_channel_count() const {
    if (!this->_is_active) {
        throw std::runtime_error("audio session is not activate.");
    }

    if (this->is_input_available()) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
    } else {
        return 0;
    }
}

bool audio::ios_session::is_input_available() const {
    if (!this->_is_active) {
        throw std::runtime_error("audio session is not activate.");
    }

    return [AVAudioSession sharedInstance].isInputAvailable;
}

enum audio::ios_session::category audio::ios_session::category() const {
    return this->_category;
}

void audio::ios_session::set_category(enum category const category) {
    this->_category = category;
}

chaining::chain_unsync_t<audio::ios_session::device_method> audio::ios_session::device_chain() {
    return this->_device_notifier->chain();
}

chaining::chain_unsync_t<audio::interruption_method> audio::ios_session::interruption_chain() {
    return this->_interruption_notifier->chain();
}

audio::ios_session::activate_result_t audio::ios_session::_set_category() {
    if (this->_is_active) {
        throw std::runtime_error("audio session is not deactivate.");
    }

    NSError *error = nil;

    if ([[AVAudioSession sharedInstance] setCategory:to_objc_category(this->_category) error:&error]) {
        return activate_result_t{nullptr};
    } else {
        NSLog(@"audio session set category error : %@", error);
        return activate_result_t{to_string((__bridge CFStringRef)(error.description ?: @""))};
    }
}

audio::ios_session::activate_result_t audio::ios_session::_set_sample_rate() {
    if (this->_is_active) {
        throw std::runtime_error("audio session is not deactivate.");
    }

    NSError *error = nil;

    if ([[AVAudioSession sharedInstance] setPreferredSampleRate:this->_preferred_sample_rate error:&error]) {
        return activate_result_t{nullptr};
    } else {
        NSLog(@"audio session set sample rate error : %@", error);
        return activate_result_t{to_string((__bridge CFStringRef)(error.description ?: @""))};
    }
}

audio::ios_session::activate_result_t audio::ios_session::_set_io_buffer_duration() {
    if (this->_is_active) {
        throw std::runtime_error("audio session is not deactivate.");
    }

    NSError *error = nil;

    double const duration = this->_preferred_io_buffer_frames / this->_preferred_sample_rate;

    if ([[AVAudioSession sharedInstance] setPreferredIOBufferDuration:duration error:&error]) {
        return activate_result_t{nullptr};
    } else {
        NSLog(@"audio session set io buffer duration error : %@", error);
        return activate_result_t{to_string((__bridge CFStringRef)(error.description ?: @""))};
    }
}

audio::ios_session::activate_result_t audio::ios_session::_set_active() {
    NSError *error = nil;

    if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        return activate_result_t{nullptr};
    } else {
        NSLog(@"audio session set active error : %@", error);
        return activate_result_t{to_string((__bridge CFStringRef)(error.description ?: @""))};
    }
}

void audio::ios_session::_set_interrupting_and_notify(bool const is_interrupting) {
    if (this->_is_interrupting != is_interrupting) {
        this->_is_interrupting = is_interrupting;
        this->_interruption_notifier->notify(is_interrupting ? interruption_method::began : interruption_method::ended);
    }
}

void audio::ios_session::_setup_interrupting() {
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

void audio::ios_session::_dispose_interrupting() {
    this->_is_interrupting = false;
    this->_impl->did_become_active_observer = std::nullopt;
    this->_impl->interruption_observer = std::nullopt;
}

audio::ios_session_ptr const &audio::ios_session::shared() {
    static ios_session_ptr const shared = ios_session_ptr(new ios_session{});
    return shared;
}

bool audio::is_output_category(enum audio::ios_session::category const category) {
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

bool audio::is_input_category(enum audio::ios_session::category const category) {
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
