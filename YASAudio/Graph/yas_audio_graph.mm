//
//  yas_audio_graph.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_graph.h"
#include "yas_audio_unit.h"
#include "yas_exception.h"
#include <mutex>
#include <map>
#include <set>
#include <string>
#include <exception>
#include <limits>
#include <experimental/optional>

#if TARGET_OS_IPHONE
#import "NSException+YASAudio.h"
#import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#include "yas_audio_device_io.h"
#endif

#include <iostream>

using namespace yas;

#pragma mark - utility

template <typename T, typename U>
static std::experimental::optional<T> _min_empty_key_in_map(std::map<T, U> &map)
{
    auto map_size = map.size();

    if (map_size == 0) {
        return std::experimental::make_optional<T>(0);
    }

    if (map_size >= std::numeric_limits<T>::max()) {
        return std::experimental::nullopt;
    }

    int next = map.rbegin()->first + 1;
    if (next == map.size()) {
        return std::experimental::make_optional<T>(next);
    }

    next = 0;
    while (map.count(next) > 0) {
        ++next;
    }
    return std::experimental::make_optional<T>(next);
}

static std::recursive_mutex _global_mutex;
static bool _interrupting;
static std::map<UInt8, std::weak_ptr<audio_graph>> _graphs;

#pragma mark - impl

class audio_graph::impl
{
   public:
    bool running;
    mutable std::recursive_mutex mutex;
    std::map<UInt16, audio_unit_ptr> units;
    std::set<audio_unit_ptr> io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::set<audio_device_io_ptr> device_ios;
#endif

    impl(const UInt8 key) : running(false), mutex(), units(), io_units(), _key(key){};

    static const bool is_interrupting()
    {
        return _interrupting;
    }

    static void start_all_graphs()
    {
#if TARGET_OS_IPHONE
        NSError *error = nil;
        if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            YASRaiseIfError(error);
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

    static void add_graph(const audio_graph_ptr &graph)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.insert(std::make_pair(graph->_impl->key(), std::weak_ptr<audio_graph>(graph)));
    }

    static void remove_graph_for_key(const UInt8 key)
    {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.erase(key);
    }

    static audio_graph_ptr graph_for_key(const UInt8 key)
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
        return _min_empty_key_in_map(units);
    }

    std::shared_ptr<audio_unit> unit_for_key(const UInt16 key) const
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);
        return units.at(key);
    }

    void add_unit_to_units(const std::shared_ptr<audio_unit> &audio_unit)
    {
        if (!audio_unit) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (audio_unit->key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not null.");
        }

        std::lock_guard<std::recursive_mutex> lock(mutex);

        auto unit_key = next_unit_key();
        if (unit_key) {
            audio_unit->set_graph_key(key());
            audio_unit->set_key(*unit_key);
            units.insert(std::make_pair(*unit_key, audio_unit));
            if (audio_unit->is_output_unit()) {
                io_units.insert(audio_unit);
            }
        }
    }

    void remove_unit_from_units(const std::shared_ptr<audio_unit> &audio_unit)
    {
        std::lock_guard<std::recursive_mutex> lock(mutex);

        if (audio_unit->key()) {
            units.erase(*audio_unit->key());
            io_units.erase(audio_unit);
            audio_unit->set_key(std::experimental::nullopt);
            audio_unit->set_graph_key(std::experimental::nullopt);
        }
    }

    void start_all_ios()
    {
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

void audio_graph::add_audio_unit(audio_unit_ptr &audio_unit)
{
    if (audio_unit->key()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is assigned.");
    }

    _impl->add_unit_to_units(audio_unit);

    audio_unit->initialize();

    if (audio_unit->is_output_unit() && is_running() && !_impl->is_interrupting()) {
        audio_unit->start();
    }
}

void audio_graph::remove_audio_unit(audio_unit_ptr &audio_unit)
{
    if (!audio_unit->key()) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : audio_unit.key is not assigned.");
    }

    audio_unit->uninitialize();

    _impl->remove_unit_from_units(audio_unit);
}

void audio_graph::remove_all_units()
{
    std::lock_guard<std::recursive_mutex> lock(_impl->mutex);

    auto it = _impl->units.begin();
    while (it != _impl->units.end()) {
        auto unit = it->second;
        ++it;
        remove_audio_unit(unit);
    }
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio_graph::add_audio_device_io(audio_device_io_ptr &audio_device_io)
{
    {
        std::lock_guard<std::recursive_mutex> lock(_impl->mutex);
        _impl->device_ios.insert(audio_device_io);
    }
    if (is_running() && !_impl->is_interrupting()) {
        audio_device_io->start();
    }
}

void audio_graph::remove_audio_device_io(audio_device_io_ptr &audio_device_io)
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

audio_graph_ptr audio_graph::create()
{
    std::lock_guard<std::recursive_mutex> lock(_global_mutex);
    auto key = _min_empty_key_in_map(_graphs);
    if (key && _graphs.count(*key) == 0) {
        auto graph = audio_graph_ptr(new audio_graph(*key));
        audio_graph::impl::add_graph(graph);
        return graph;
    }
    return nullptr;
}
