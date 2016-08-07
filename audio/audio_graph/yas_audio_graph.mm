//
//  yas_audio_graph.mm
//

#include "yas_audio_graph.h"
#include "yas_audio_unit.h"
#include "yas_stl_utils.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include "yas_objc_ptr.h"
#endif

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device_io.h"
#endif

using namespace yas;

namespace yas {
namespace audio {
    static std::recursive_mutex _global_mutex;
    static bool _interrupting;
    static std::map<uint8_t, weak<graph>> _graphs;
#if TARGET_OS_IPHONE
    static objc_ptr<> _did_become_active_observer;
    static objc_ptr<> _interruption_observer;
#endif
}
}

#pragma mark - impl

struct audio::graph::impl : base::impl {
   public:
    impl(uint8_t const key) : _key(key){};

    ~impl() {
        stop_all_ios();
        remove_graph_for_key(key());
        remove_all_units();
    }

    static std::shared_ptr<impl> make_shared() {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        auto key = min_empty_key(_graphs);
        if (key && _graphs.count(*key) == 0) {
            return std::make_shared<impl>(*key);
        }
        return nullptr;
    }

#if TARGET_OS_IPHONE
    static void setup_notifications() {
        if (!_did_become_active_observer) {
            auto const lambda = [](NSNotification *note) { start_all_graphs(); };
            id observer =
                [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:std::move(lambda)];
            _did_become_active_observer.set_object(observer);
        }

        if (!_interruption_observer) {
            auto const lambda = [](NSNotification *note) {
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
                                                              usingBlock:std::move(lambda)];
            _interruption_observer.set_object(observer);
        }
    }
#endif

    static bool const is_interrupting() {
        return _interrupting;
    }

    static void start_all_graphs() {
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
                        graph.impl_ptr<impl>()->start_all_ios();
                    }
                }
            }
        }

        _interrupting = false;
    }

    static void stop_all_graphs() {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        for (auto const &pair : _graphs) {
            if (auto const graph = pair.second.lock()) {
                graph.impl_ptr<impl>()->stop_all_ios();
            }
        }
    }

    static void add_graph(graph const &graph) {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.insert(std::make_pair(graph.impl_ptr<impl>()->key(), to_weak(graph)));
    }

    static void remove_graph_for_key(uint8_t const key) {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        _graphs.erase(key);
    }

    static graph graph_for_key(uint8_t const key) {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        if (_graphs.count(key) > 0) {
            auto weak_graph = _graphs.at(key);
            return weak_graph.lock();
        }
        return nullptr;
    }

    std::experimental::optional<uint16_t> next_unit_key() {
        std::lock_guard<std::recursive_mutex> lock(_global_mutex);
        return min_empty_key(_units);
    }

    unit unit_for_key(uint16_t const key) const {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _units.at(key);
    }

    void add_unit_to_units(unit &unit) {
        if (!unit) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        auto &unt = unit.manageable();

        if (unt.key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : unit.key is not null.");
        }

        std::lock_guard<std::recursive_mutex> lock(_mutex);

        auto unit_key = next_unit_key();
        if (unit_key) {
            unt.set_graph_key(key());
            unt.set_key(*unit_key);
            auto pair = std::make_pair(*unit_key, unit);
            _units.insert(pair);
            if (unit.is_output_unit()) {
                _io_units.insert(pair);
            }
        }
    }

    void remove_unit_from_units(unit &unit) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        auto &manageable_unit = unit.manageable();

        if (auto key = manageable_unit.key()) {
            _units.erase(*key);
            _io_units.erase(*key);
            manageable_unit.set_key(nullopt);
            manageable_unit.set_graph_key(nullopt);
        }
    }

    void add_audio_unit(unit &unit) {
        auto &manageable_unit = unit.manageable();

        if (manageable_unit.key()) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : unit.key is already assigned.");
        }

        add_unit_to_units(unit);

        manageable_unit.initialize();

        if (unit.is_output_unit() && _running && !is_interrupting()) {
            unit.start();
        }
    }

    void remove_audio_unit(unit &unit) {
        unit.manageable().uninitialize();

        remove_unit_from_units(unit);
    }

    void remove_all_units() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        for_each(_units, [this](auto const &it) {
            auto unit = it->second;
            auto next = std::next(it);
            remove_audio_unit(unit);
            return next;
        });
    }

    void start_all_ios() {
#if TARGET_OS_IPHONE
        setup_notifications();
#endif

        for (auto &pair : _io_units) {
            auto &unit = pair.second;
            unit.start();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : _device_ios) {
            device_io.start();
        }
#endif
    }

    void stop_all_ios() {
        for (auto &pair : _io_units) {
            auto &unit = pair.second;
            unit.stop();
        }
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        for (auto &device_io : _device_ios) {
            device_io.stop();
        }
#endif
    }

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void add_audio_device_io(device_io &device_io) {
        {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            _device_ios.insert(device_io);
        }
        if (_running && !is_interrupting()) {
            device_io.start();
        }
    }

    void remove_audio_device_io(device_io &device_io) {
        device_io.stop();
        {
            std::lock_guard<std::recursive_mutex> lock(_mutex);
            _device_ios.erase(device_io);
        }
    }
#endif

    void start() {
        if (!_running) {
            _running = true;
            start_all_ios();
        }
    }

    void stop() {
        if (_running) {
            _running = false;
            stop_all_ios();
        }
    }

    uint8_t key() const {
        return _key;
    }

    bool is_running() const {
        return _running;
    }

   private:
    uint8_t _key;
    bool _running = false;
    mutable std::recursive_mutex _mutex;
    std::map<uint16_t, unit> _units;
    std::map<uint16_t, unit> _io_units;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::unordered_set<device_io> _device_ios;
#endif
};

#pragma mark - main

audio::graph::graph() : base(impl::make_shared()) {
    if (impl_ptr()) {
        impl::add_graph(*this);
    }
}

audio::graph::graph(std::nullptr_t) : base(nullptr) {
}

audio::graph::~graph() = default;

void audio::graph::add_audio_unit(unit &unit) {
    impl_ptr<impl>()->add_audio_unit(unit);
}

void audio::graph::remove_audio_unit(unit &unit) {
    impl_ptr<impl>()->remove_audio_unit(unit);
}

void audio::graph::remove_all_units() {
    impl_ptr<impl>()->remove_all_units();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

void audio::graph::add_audio_device_io(device_io &device_io) {
    impl_ptr<impl>()->add_audio_device_io(device_io);
}

void audio::graph::remove_audio_device_io(device_io &device_io) {
    impl_ptr<impl>()->remove_audio_device_io(device_io);
}

#endif

void audio::graph::start() {
    impl_ptr<impl>()->start();
}

void audio::graph::stop() {
    impl_ptr<impl>()->stop();
}

bool audio::graph::is_running() const {
    return impl_ptr<impl>()->is_running();
}

void audio::graph::audio_unit_render(render_parameters &render_parameters) {
    raise_if_main_thread();

    if (auto graph = impl::graph_for_key(render_parameters.render_id.graph)) {
        if (auto unit = graph.impl_ptr<impl>()->unit_for_key(render_parameters.render_id.unit)) {
            unit.callback_render(render_parameters);
        }
    }
}
