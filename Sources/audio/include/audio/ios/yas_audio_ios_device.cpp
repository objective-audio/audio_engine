//
//  yas_audio_ios_device.mm
//

#include "yas_audio_ios_device.h"

#if TARGET_OS_IPHONE

#include <audio/io/yas_audio_renewable_device.h>
#include <audio/ios/yas_audio_ios_io_core.h>

using namespace yas;
using namespace yas::audio;

ios_device::ios_device(ios_device_session_ptr const &device_session, interruptor_ptr const &interruptor)
    : _session(device_session), _interruptor(interruptor) {
    this->_canceller = device_session
                           ->observe_device([this](auto const &session_method) {
                               switch (session_method) {
                                   case ios_session::device_method::activate:
                                   case ios_session::device_method::route_change:
                                       this->_notifier->notify(method::updated);
                                       break;
                                   case ios_session::device_method::media_service_were_lost:
                                   case ios_session::device_method::media_service_were_reset:
                                   case ios_session::device_method::deactivate:
                                       this->_session = std::nullopt;
                                       this->_notifier->notify(method::lost);
                                       break;
                               }
                           })
                           .end();
}

std::optional<audio::ios_device_session_ptr> const &ios_device::session() const {
    return this->_session;
}

double ios_device::sample_rate() const {
    if (auto const &session = this->session()) {
        return session.value()->sample_rate();
    } else {
        return 0;
    }
}

std::optional<format> ios_device::input_format() const {
    if (auto const &session = this->session()) {
        auto const sample_rate = session.value()->sample_rate();
        auto const ch_count = session.value()->input_channel_count();

        if (sample_rate > 0.0 && ch_count > 0) {
            return format({.sample_rate = sample_rate, .channel_count = ch_count});
        }
    }

    return std::nullopt;
}

std::optional<format> ios_device::output_format() const {
    if (auto const &session = this->session()) {
        auto const sample_rate = session.value()->sample_rate();
        auto const ch_count = session.value()->output_channel_count();

        if (sample_rate > 0.0 && ch_count > 0) {
            return format({.sample_rate = sample_rate, .channel_count = ch_count});
        }
    }

    return std::nullopt;
}

std::optional<audio::interruptor_ptr> const &ios_device::interruptor() const {
    return this->_interruptor;
}

io_core_ptr ios_device::make_io_core() const {
    return ios_io_core::make_shared(this->_weak_device.lock());
}

observing::endable ios_device::observe_io_device(observing::caller<method>::handler_f &&handler) {
    return this->_notifier->observe(std::move(handler));
}

ios_device_ptr ios_device::make_shared(ios_session_ptr const &session) {
    return make_shared(session, session);
}

ios_device_ptr ios_device::make_shared(ios_device_session_ptr const &device_session,
                                       interruptor_ptr const &interruptor) {
    auto shared = std::shared_ptr<ios_device>(new ios_device{device_session, interruptor});
    shared->_weak_device = shared;
    return shared;
}

audio::io_device_ptr ios_device::make_renewable_device(ios_session_ptr const &session) {
    return audio::renewable_device::make_shared(
        [session]() { return ios_device::make_shared(session); },
        [](io_device_ptr const &device, renewable_device::method_f const &handler) {
            auto canceller = device
                                 ->observe_io_device([handler](auto const &method) {
                                     switch (method) {
                                         case io_device::method::updated:
                                             handler(renewable_device::method::notify);
                                             break;
                                         case io_device::method::lost:
                                             handler(renewable_device::method::renewal);
                                             break;
                                     }
                                 })
                                 .end();
            return std::vector<observing::cancellable_ptr>{canceller};
        });
}

#endif
