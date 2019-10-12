//
//  yas_audio_avf_device.mm
//

#include "yas_audio_avf_device.h"

#if TARGET_OS_IPHONE

#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>

using namespace yas;

struct audio::avf_device::impl {
    std::vector<objc_ptr<id<NSObject>>> _observers;

    ~impl() {
        for (auto const &observer : this->_observers) {
            [NSNotificationCenter.defaultCenter removeObserver:observer.object()];
        }
    }
};

audio::avf_device::avf_device() : _impl(std::make_unique<impl>()) {
}

double audio::avf_device::sample_rate() const {
    return [AVAudioSession sharedInstance].sampleRate;
}

uint32_t audio::avf_device::input_channel_count() const {
    if ([AVAudioSession sharedInstance].isInputAvailable) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
    } else {
        return 0;
    }
}

uint32_t audio::avf_device::output_channel_count() const {
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
}

std::optional<audio::format> audio::avf_device::input_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->input_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

std::optional<audio::format> audio::avf_device::output_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->output_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

void audio::avf_device::_prepare(avf_device_ptr const &shared) {
    auto weak_device = to_weak(shared);

    auto route_change_observer = objc_ptr<id<NSObject>>([weak_device] {
        return [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification
                                                               object:AVAudioSession.sharedInstance
                                                                queue:NSOperationQueue.mainQueue
                                                           usingBlock:[weak_device](NSNotification *note) {
                                                               if (avf_device_ptr const device = weak_device.lock()) {
                                                                   device->_notifier->notify(method::route_change);
                                                               }
                                                           }];
    });

    auto lost_observer = objc_ptr<id<NSObject>>([weak_device] {
        return [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionMediaServicesWereLostNotification
                                                               object:AVAudioSession.sharedInstance
                                                                queue:NSOperationQueue.mainQueue
                                                           usingBlock:[weak_device](NSNotification *note) {
                                                               if (auto const device = weak_device.lock()) {
                                                                   device->_notifier->notify(method::lost);
                                                               }
                                                           }];
    });

    auto reset_observer = objc_ptr<id<NSObject>>([weak_device] {
        return [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                                                               object:AVAudioSession.sharedInstance
                                                                queue:NSOperationQueue.mainQueue
                                                           usingBlock:[weak_device](NSNotification *note) {
                                                               if (auto const device = weak_device.lock()) {
                                                                   device->_notifier->notify(method::lost);
                                                               }
                                                           }];
    });

    this->_impl->_observers = {route_change_observer, lost_observer, reset_observer};
}

audio::avf_device_ptr audio::avf_device::make_shared() {
    auto shared = std::shared_ptr<avf_device>(new avf_device{});
    shared->_prepare(shared);
    return shared;
}

chaining::chain_unsync_t<audio::avf_device::method> audio::avf_device::chain() {
    return this->_notifier->chain();
}

#endif
