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

namespace yas::audio::global_graph {
static std::recursive_mutex _mutex;
static std::map<uint8_t, std::weak_ptr<graph>> _graphs;
#if TARGET_OS_IPHONE
static objc_ptr<> _did_become_active_observer;
static objc_ptr<> _interruption_observer;
#endif

static std::optional<uint8_t> min_empty_graph_key() {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    return min_empty_key(global_graph::_graphs);
}

static void add_graph(graph_ptr const &graph) {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    global_graph::_graphs.insert(std::make_pair(graph->key(), to_weak(graph)));
}

static void remove_graph_for_key(uint8_t const key) {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    global_graph::_graphs.erase(key);
}
}

#pragma mark - core

struct audio::graph::core {
    objc_ptr<> _did_become_active_observer;
    objc_ptr<> _interruption_observer;
};

#pragma mark - main

audio::graph::graph(uint8_t const key) : _key(key), _core(std::make_unique<core>()) {
}

audio::graph::~graph() {
    this->stop_all_ios();
    global_graph::remove_graph_for_key(this->_key);
}

void audio::graph::_prepare(graph_ptr const &shared) {
    global_graph::add_graph(shared);
}

void audio::graph::_setup_notifications() {
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
}

void audio::graph::add_io(io_ptr const &io) {
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        this->_ios.insert(io);
    }
    if (this->_running && !this->_is_interrupting) {
        io->start();
    }
}

void audio::graph::remove_io(io_ptr const &io) {
    io->stop();
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
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

uint8_t audio::graph::key() const {
    return this->_key;
}

void audio::graph::start_all_ios() {
#if TARGET_OS_IPHONE
    this->_setup_notifications();
#endif

    for (auto const &io : this->_ios) {
        io->start();
    }
}

void audio::graph::stop_all_ios() {
    for (auto &io : this->_ios) {
        io->stop();
    }
}

audio::graph_ptr audio::graph::make_shared() {
    if (auto key = global_graph::min_empty_graph_key()) {
        auto shared = graph_ptr(new graph{*key});
        shared->_prepare(shared);
        return shared;
    } else {
        return nullptr;
    }
}
