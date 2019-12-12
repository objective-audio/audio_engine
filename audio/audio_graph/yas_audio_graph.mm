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
static bool _is_interrupting;
static std::map<uint8_t, std::weak_ptr<graph>> _graphs;
#if TARGET_OS_IPHONE
static objc_ptr<> _did_become_active_observer;
static objc_ptr<> _interruption_observer;
#endif

static std::optional<uint8_t> min_empty_graph_key() {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    return min_empty_key(global_graph::_graphs);
}

#if TARGET_OS_IPHONE
static void start_all_graphs() {
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"%@", error);
        return;
    }

    {
        std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
        for (auto &pair : global_graph::_graphs) {
            if (auto graph = pair.second.lock()) {
                if (graph->is_running()) {
                    audio::interruptable_graph::cast(graph)->start_all_ios();
                }
            }
        }
    }

    global_graph::_is_interrupting = false;
}

static void stop_all_graphs() {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    for (auto const &pair : global_graph::_graphs) {
        if (auto const graph = pair.second.lock()) {
            audio::interruptable_graph::cast(graph)->stop_all_ios();
        }
    }
}
#endif

static void add_graph(graph_ptr const &graph) {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    global_graph::_graphs.insert(std::make_pair(graph->key(), to_weak(graph)));
}

static void remove_graph_for_key(uint8_t const key) {
    std::lock_guard<std::recursive_mutex> lock(global_graph::_mutex);
    global_graph::_graphs.erase(key);
}

#if TARGET_OS_IPHONE
static void setup_notifications() {
    if (!global_graph::_did_become_active_observer) {
        auto const lambda = [](NSNotification *note) { global_graph::start_all_graphs(); };
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:std::move(lambda)];
        global_graph::_did_become_active_observer.set_object(observer);
    }

    if (!global_graph::_interruption_observer) {
        auto const lambda = [](NSNotification *note) {
            NSDictionary *info = note.userInfo;
            NSNumber *typeNum = [info valueForKey:AVAudioSessionInterruptionTypeKey];
            AVAudioSessionInterruptionType interruptionType =
                static_cast<AVAudioSessionInterruptionType>([typeNum unsignedIntegerValue]);

            if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
                global_graph::_is_interrupting = true;
                global_graph::stop_all_graphs();
            } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                    global_graph::start_all_graphs();
                    global_graph::_is_interrupting = false;
                }
            }
        };
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:std::move(lambda)];
        global_graph::_interruption_observer.set_object(observer);
    }
}
#endif
}

#pragma mark - main

audio::graph::graph(uint8_t const key) : _key(key) {
}

audio::graph::~graph() {
    this->stop_all_ios();
    global_graph::remove_graph_for_key(this->_key);
}

void audio::graph::_prepare(graph_ptr const &shared) {
    global_graph::add_graph(shared);
}

void audio::graph::add_io(io_ptr const &io) {
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        this->_ios.insert(io);
    }
    if (this->_running && !global_graph::_is_interrupting) {
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
    global_graph::setup_notifications();
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
