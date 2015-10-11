//
//  yas_audio_graph.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_graph.h"
#include "yas_audio_unit.h"
#include "yas_exception.h"
#include "yas_stl_utils.h"
#include <mutex>
#include <list>
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
static std::map<UInt8, audio_graph::weak> _graphs;
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
    std::map<UInt16, audio_unit> units;
    std::map<UInt16, audio_unit> io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::list<audio_device_io> device_ios;
#endif

    impl(const UInt8 key) : running(false), mutex(), units(), io_units(), _key(key){};

    ~impl()
    {
        stop_all_ios();
        remove_graph_for_key(key());
        remove_all_units();
    }

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
                    if (graph.is_running()) {
                        graph._impl->start_all_ios();
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
                graph._impl->stop_all_ios();
            }
        }
    }

    static void add_graph(const audio_graph &graph)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.insert(std::make_pair(graph._impl->key(), audio_graph::weak(graph)));
    }

    static void remove_graph_for_key(const UInt8 key)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.erase(key);
    }

    static audio_graph graph_for_key(const UInt8 key)
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

    audio_unit unit_for_key(const UInt16 key) const
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return units.at(key);
    }

    void add_unit_to_units(audio_unit &unit)
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
            auto pair = std::make_pair(*unit_key, unit);
            units.insert(pair);
            if (unit.is_output_unit()) {
                io_units.insert(pair);
            }
        }
    }

    void remove_unit_from_units(audio_unit &unit)
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);

        if (auto key = audio_unit::private_access::key(unit)) {
            units.erase(*key);
            io_units.erase(*key);
            audio_unit::private_access::set_key(unit, nullopt);
            audio_unit::private_access::set_graph_key(unit, nullopt);
        }
    }

    void remove_audio_unit(audio_unit &unit)
    {
        if (!audio_unit::private_access::key(unit)) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not assigned.");
        }

        audio_unit::private_access::uninitialize(unit);

        remove_unit_from_units(unit);
    }

    void remove_all_units()
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);

        enumerate(units, [this](const auto &it) {
            auto unit = it->second;
            auto next = std::next(it);
            remove_audio_unit(unit);
            return next;
        });
    }

    void start_all_ios()
    {
#if TARGET_OS_IPHONE
        setup_notifications();
#endif

        for (auto &pair : io_units) {
            auto &audio_unit = pair.second;
            audio_unit.start();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : device_ios) {
            device_io.start();
        }
#endif
    }

    void stop_all_ios()
    {
        for (auto &pair : io_units) {
            auto &audio_unit = pair.second;
            audio_unit.stop();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : device_ios) {
            device_io.stop();
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

audio_graph::weak::weak() : _impl()
{
}

audio_graph::weak::weak(const audio_graph &graph) : _impl(graph._impl)
{
}

audio_graph audio_graph::weak::lock() const
{
    return audio_graph(_impl.lock());
}

void audio_graph::weak::reset()
{
    _impl.reset();
}

#pragma mark - constructor

audio_graph::audio_graph(std::nullptr_t) : _impl(nullptr)
{
}

audio_graph::audio_graph(const std::shared_ptr<audio_graph::impl> &impl) : _impl(impl)
{
}

bool audio_graph::operator==(const audio_graph &other) const
{
    return _impl && other._impl && _impl == other._impl;
}

bool audio_graph::operator!=(const audio_graph &other) const
{
    return !_impl || !other._impl || _impl != other._impl;
}

audio_graph::operator bool() const
{
    return _impl != nullptr;
}

void audio_graph::prepare()
{
    std::lock_guard<std::recursive_mutex> lock(_global_mutex);
    if (!_impl) {
        auto key = min_empty_key(_graphs);
        if (key && _graphs.count(*key) == 0) {
            _impl = std::make_shared<impl>(*key);
            audio_graph::impl::add_graph(*this);
        }
    }
}

void audio_graph::add_audio_unit(audio_unit &unit)
{
    if (audio_unit::private_access::key(unit)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is assigned.");
    }

    _impl->add_unit_to_units(unit);

    audio_unit::private_access::initialize(unit);

    if (unit.is_output_unit() && is_running() && !_impl->is_interrupting()) {
        unit.start();
    }
}

void audio_graph::remove_audio_unit(audio_unit &unit)
{
    _impl->remove_audio_unit(unit);
}

void audio_graph::remove_all_units()
{
    _impl->remove_all_units();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio_graph::add_audio_device_io(audio_device_io &device_io)
{
    {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        _impl->device_ios.push_back(device_io);
    }
    if (is_running() && !_impl->is_interrupting()) {
        device_io.start();
    }
}

void audio_graph::remove_audio_device_io(audio_device_io &device_io)
{
    device_io.stop();
    {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        erase_if(_impl->device_ios,
                 [&device_io](const auto &device_io_in_vec) { return device_io == device_io_in_vec; });
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
        auto unit = graph._impl->unit_for_key(render_parameters.render_id.unit);
        if (unit) {
            unit.callback_render(render_parameters);
        }
    }
}
