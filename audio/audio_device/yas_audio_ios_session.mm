//
//  yas_audio_ios_session.mm
//

#include "yas_audio_ios_session.h"

#if TARGET_OS_IPHONE

#import <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <vector>

using namespace yas;

struct audio::ios_session::impl {
    std::vector<objc_ptr<id<NSObject>>> observers;

    ~impl() {
        for (auto const &observer : this->observers) {
            [NSNotificationCenter.defaultCenter removeObserver:observer.object()];
        }
    }
};

audio::ios_session::ios_session()
    : _impl(std::make_unique<impl>()), _notifier(chaining::notifier<method>::make_shared()) {
    auto route_change_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter
            addObserverForName:AVAudioSessionRouteChangeNotification
                        object:AVAudioSession.sharedInstance
                         queue:NSOperationQueue.mainQueue
                    usingBlock:[this](NSNotification *note) { this->_notifier->notify(method::route_change); }];
    });

    auto lost_observer = objc_ptr<id<NSObject>>([this] {
        return [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionMediaServicesWereLostNotification
                                                               object:AVAudioSession.sharedInstance
                                                                queue:NSOperationQueue.mainQueue
                                                           usingBlock:[this](NSNotification *note) {
                                                               this->_notifier->notify(method::media_service_were_lost);
                                                           }];
    });

    auto reset_observer = objc_ptr<id<NSObject>>([this] {
        return
            [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                                                            object:AVAudioSession.sharedInstance
                                                             queue:NSOperationQueue.mainQueue
                                                        usingBlock:[this](NSNotification *note) {
                                                            this->_notifier->notify(method::media_service_were_reset);
                                                        }];
    });

    this->_impl->observers = {route_change_observer, lost_observer, reset_observer};
}

double audio::ios_session::sample_rate() const {
    return [AVAudioSession sharedInstance].sampleRate;
}

uint32_t audio::ios_session::output_channel_count() const {
    return static_cast<uint32_t>([AVAudioSession sharedInstance].outputNumberOfChannels);
}

uint32_t audio::ios_session::input_channel_count() const {
    if ([AVAudioSession sharedInstance].isInputAvailable) {
        return static_cast<uint32_t>([AVAudioSession sharedInstance].inputNumberOfChannels);
    } else {
        return 0;
    }
}

chaining::chain_unsync_t<audio::ios_session::method> audio::ios_session::chain() {
    return this->_notifier->chain();
}

audio::ios_session_ptr audio::ios_session::make_shared() {
    return ios_session_ptr(new ios_session{});
}

#endif
