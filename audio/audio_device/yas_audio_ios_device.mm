//
//  yas_audio_ios_device.mm
//

#include "yas_audio_ios_device.h"

#if TARGET_OS_IPHONE

#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>

using namespace yas;

struct audio::ios_device::impl {
    std::vector<objc_ptr<id<NSObject>>> observers;

    ~impl() {
        for (auto const &observer : this->observers) {
            [NSNotificationCenter.defaultCenter removeObserver:observer.object()];
        }
    }
};

audio::ios_device::ios_device() : _impl(std::make_unique<impl>()) {
}

double audio::ios_device::sample_rate() const {
    return [AVAudioSession sharedInstance].sampleRate;
}

uint32_t audio::ios_device::input_channel_count() const {
    if ([AVAudioSession sharedInstance].isInputAvailable) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
    } else {
        return 0;
    }
}

uint32_t audio::ios_device::output_channel_count() const {
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
}

std::optional<audio::format> audio::ios_device::input_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->input_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

std::optional<audio::format> audio::ios_device::output_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->output_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

audio::io_core_ptr audio::ios_device::make_io_core() const {
    return ios_io_core::make_shared(this->_weak_device.lock());
}

chaining::chain_unsync_t<audio::io_device::method> audio::ios_device::io_device_chain() {
    return this->_notifier->chain();
}

void audio::ios_device::_prepare(ios_device_ptr const &shared) {
    auto weak_device = to_weak(shared);
    this->_weak_device = weak_device;

    auto route_change_observer = objc_ptr<id<NSObject>>([weak_device] {
        return [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification
                                                               object:AVAudioSession.sharedInstance
                                                                queue:NSOperationQueue.mainQueue
                                                           usingBlock:[weak_device](NSNotification *note) {
                                                               if (auto const device = weak_device.lock()) {
                                                                   device->_notifier->notify(method::updated);
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

    this->_impl->observers = {route_change_observer, lost_observer, reset_observer};
}

audio::ios_device_ptr audio::ios_device::make_shared() {
    auto shared = std::shared_ptr<ios_device>(new ios_device{});
    shared->_prepare(shared);
    return shared;
}

#endif
