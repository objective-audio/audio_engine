//
//  yas_audio_graph.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_graph.h"
#include "yas_audio_unit.h"
#include "yas_exception.h"
#include "yas_stl_utils.h"
#include <mutex>
#include <set>
#include <string>
#include <exception>
#include <limits>

#if TARGET_OS_IPHONE
#include "yas_objc_container.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
#include "yas_audio_device_io.h"
#endif

#include <iostream>

using namespace yas;

static std::recursive_mutex _global_mutex;
static bool _interrupting;
static std::map<UInt8, std::weak_ptr<audio_graph>> _graphs;
#if TARGET_OS_IPHONE
static yas::objc_strong_container _did_become_active_observer;
static yas::objc_strong_container _interruption_observer;
#endif

#pragma mark - impl

class audio_graph::impl
{
   public:
    bool running;
    mutable std::recursive_mutex mutex;
    std::map<UInt16, audio_unit_sptr> units;
    std::set<audio_unit_sptr> io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::set<audio_device_io_sptr> device_ios;
#endif

    impl(const UInt8 key) : running(false), mutex(), units(), io_units(), _key(key){};

#if TARGET_OS_IPHONE
    static void setup_notifications()
    {
        if (!_did_become_active_observer) {
            const auto lambda = [](NSNotification *note) { start_all_graphs(); };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:lambda];
            _did_become_active_observer = yas::objc_strong_container(observer);
        }

        if (!_interruption_observer) {
            const auto lambda = [](NSNotification *note) {
                NSDictionary *info = note.userInfo;
                NSNumber *typeNum = [info valueForKey:AVAudioSessionInterruptionTypeKey];
                AVAudioSessionInterruptionType interruptionType =
                    static_cast<AVAudioSessionInterruptionType>([typeNum unsignedIntegerValue]);

                if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
                    _interrupting = true;
                    stop_all_graphs();
                } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
                    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                        start_all_graphs();
                        _interrupting = false;
                    }
                }
            };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:lambda];
            _interruption_observer = yas::objc_strong_container(observer);
        }
    }
#endif

    static const bool is_interrupting()
    {
        return _interrupting;
    }

    static void start_all_graphs()
    {
#if TARGET_OS_IPHONE
        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            NSLog(@"%@", error);
            return;
        }
#endif

        {
            std::lock_guard<std::recursive_mutex> lock(_global_mutex);
            for (auto &pair : _graphs) {
                if (auto graph = pair.second.lock()) {
                    if (graph->is_running()) {
                        graph->_impl->start_all_ios();
                    }
                }
            }
        }

        _interrupting = false;
    }

    static void stop_all_graphs()
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        for (const auto &pair : _graphs) {
            if (const auto graph = pair.second.lock()) {
                graph->_impl->stop_all_ios();
            }
        }
    }

    static void add_graph(const audio_graph_sptr &graph)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.insert(std::make_pair(graph->_impl->key(), std::weak_ptr<audio_graph>(graph)));
    }

    static void remove_graph_for_key(const UInt8 key)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.erase(key);
    }

    static audio_graph_sptr graph_for_key(const UInt8 key)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        if (_graphs.count(key) > 0) {
            auto weak_graph = _graphs.at(key);
            return weak_graph.lock();
        }
        return nullptr;
    }

    std::experimental::optional<UInt16> next_unit_key()
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        return min_empty_key(units);
    }

    std::shared_ptr<audio_unit> unit_for_key(const UInt16 key) const
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return units.at(key);
    }

    void add_unit_to_units(const std::shared_ptr<audio_unit> &unit)
    {
        if (!unit) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (audio_unit::private_access::key(unit)) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not null.");
        }

        std::lock_guard<std::recursive_mutex> lock(mutex);

        auto unit_key = next_unit_key();
        if (unit_key) {
            audio_unit::private_access::set_graph_key(unit, key());
            audio_unit::private_access::set_key(unit, *unit_key);
            units.insert(std::make_pair(*unit_key, unit));
            if (unit->is_output_unit()) {
                io_units.insert(unit);
            }
        }
    }

    void remove_unit_from_units(const std::shared_ptr<audio_unit> &unit)
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);

        if (auto key = audio_unit::private_access::key(unit)) {
            units.erase(*key);
            io_units.erase(unit);
            audio_unit::private_access::set_key(unit, nullopt);
            audio_unit::private_access::set_graph_key(unit, nullopt);
        }
    }

    void start_all_ios()
    {
#if TARGET_OS_IPHONE
        setup_notifications();
#endif

        for (const auto &audio_unit : io_units) {
            audio_unit->start();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (const auto &device_io : device_ios) {
            device_io->start();
        }
#endif
    }

    void stop_all_ios()
    {
        for (const auto &audio_unit : io_units) {
            audio_unit->stop();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (const auto &device_io : device_ios) {
            device_io->stop();
        }
#endif
    }

    UInt8 key() const
    {
        return _key;
    }

   private:
    UInt8 _key;
};

#pragma mark - constructor

audio_graph::audio_graph(const UInt8 key) : _impl(std::make_unique<impl>(key))
{
}

audio_graph::~audio_graph()
{
    _impl->stop_all_ios();
    impl::remove_graph_for_key(_impl->key());
    remove_all_units();
}

void audio_graph::add_audio_unit(const audio_unit_sptr &unit)
{
    if (audio_unit::private_access::key(unit)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is assigned.");
    }

    _impl->add_unit_to_units(unit);

    audio_unit::private_access::initialize(unit);

    if (unit->is_output_unit() && is_running() && !_impl->is_interrupting()) {
        unit->start();
    }
}

void audio_graph::remove_audio_unit(const audio_unit_sptr &unit)
{
    if (!audio_unit::private_access::key(unit)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not assigned.");
    }

    audio_unit::private_access::uninitialize(unit);

    _impl->remove_unit_from_units(unit);
}

void audio_graph::remove_all_units()
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);

    enumerate(_impl->units, [this](const auto &it) {
        auto unit = it->second;
        auto next = std::next(it);
        remove_audio_unit(unit);
        return next;
    });
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio_graph::add_audio_device_io(audio_device_io_sptr &audio_device_io)
{
    {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        _impl->device_ios.insert(audio_device_io);
    }
    if (is_running() && !_impl->is_interrupting()) {
        audio_device_io->start();
    }
}

void audio_graph::remove_audio_device_io(audio_device_io_sptr &audio_device_io)
{
    audio_device_io->stop();
    {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        _impl->device_ios.erase(audio_device_io);
    }
}

#endif

void audio_graph::start()
{
    if (!_impl->running) {
        _impl->running = true;
        _impl->start_all_ios();
    }
}

void audio_graph::stop()
{
    if (_impl->running) {
        _impl->running = false;
        _impl->stop_all_ios();
    }
}

bool audio_graph::is_running() const
{
    return _impl->running;
}

void audio_graph::audio_unit_render(render_parameters &render_parameters)
{
    yas_raise_if_main_thread;

    auto graph = impl::graph_for_key(render_parameters.render_id.graph);
    if (graph) {
        auto unit = graph->_impl->unit_for_key(render_parameters.render_id.unit);
        if (unit) {
            unit->callback_render(render_parameters);
        }
    }
}

audio_graph_sptr audio_graph::create()
{
    std::lock_guard<std::recursive_mutex> lock(_global_mutex);
    auto key = min_empty_key(_graphs);
    if (key && _graphs.count(*key) == 0) {
        auto graph = audio_graph_sptr(new audio_graph(*key));
        audio_graph::impl::add_graph(graph);
        return graph;
    }
    return nullptr;
}
