//
//  yas_audio_graph.mm
//

#include "yas_audio_graph.h"
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_io.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <cpp_utils/yas_objc_ptr.h>
#endif

using namespace yas;

#pragma mark - core

struct audio::graph::core {
#if TARGET_OS_IPHONE
    objc_ptr<> _did_become_active_observer;
    objc_ptr<> _interruption_observer;
#endif
};

#pragma mark - main

audio::graph::graph() : _core(std::make_unique<core>()) {
}

audio::graph::~graph() {
    this->stop_all_ios();
}

void audio::graph::_setup_notifications() {
#if TARGET_OS_IPHONE
    if (!this->_core->_did_become_active_observer) {
        auto const lambda = [this](NSNotification *note) {
            if (this->_running) {
                this->start_all_ios();
            }
        };
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:std::move(lambda)];
        this->_core->_did_become_active_observer = objc_ptr<>(observer);
    }

    if (!this->_core->_interruption_observer) {
        auto const lambda = [this](NSNotification *note) {
            NSNumber *typeNum = [note.userInfo valueForKey:AVAudioSessionInterruptionTypeKey];
            AVAudioSessionInterruptionType interruptionType =
                static_cast<AVAudioSessionInterruptionType>([typeNum unsignedIntegerValue]);

            switch (interruptionType) {
                case AVAudioSessionInterruptionTypeBegan:
                    this->_is_interrupting = true;
                    this->stop_all_ios();
                    break;
                case AVAudioSessionInterruptionTypeEnded:
                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                        if (this->_running) {
                            this->start_all_ios();
                        }
                        this->_is_interrupting = false;
                    }
                    break;
            }
        };
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:std::move(lambda)];
        this->_core->_interruption_observer = objc_ptr<>(observer);
    }
#endif
}

void audio::graph::_dispose_notifications() {
#if TARGET_OS_IPHONE
    this->_core->_did_become_active_observer = nullptr;
    this->_core->_interruption_observer = nullptr;
#endif
}

void audio::graph::add_io(io_ptr const &io) {
    if (this->_ios.count(io) == 0) {
        this->_ios.insert(io);

        if (this->_running && !this->_is_interrupting) {
            io->start();
        }
    }
}

void audio::graph::remove_io(io_ptr const &io) {
    if (this->_ios.count(io) > 0) {
        io->stop();

        this->_ios.erase(io);
    }
}

void audio::graph::start() {
    if (!this->_running) {
        this->_running = true;
        this->start_all_ios();
    }
}

void audio::graph::stop() {
    if (this->_running) {
        this->_running = false;
        this->stop_all_ios();
    }
}

bool audio::graph::is_running() const {
    return this->_running;
}

void audio::graph::start_all_ios() {
    this->_setup_notifications();

    for (auto const &io : this->_ios) {
        io->start();
    }
}

void audio::graph::stop_all_ios() {
    for (auto &io : this->_ios) {
        io->stop();
    }

    this->_dispose_notifications();
}

audio::graph_ptr audio::graph::make_shared() {
    return graph_ptr(new graph{});
}
