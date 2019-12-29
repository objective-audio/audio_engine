//
//  yas_audio_ios_device.mm
//

#include "yas_audio_ios_device.h"

#if TARGET_OS_IPHONE

#include "yas_audio_ios_io_core.h"
#include "yas_audio_ios_session.h"

using namespace yas;

audio::ios_device::ios_device() : _session(ios_session::make_shared()) {
    this->_observer = this->_session->chain()
                          .perform([this](auto const &session_method) {
                              switch (session_method) {
                                  case ios_session::method::route_change:
                                      this->_notifier->notify(method::updated);
                                      break;
                                  case ios_session::method::media_service_were_lost:
                                  case ios_session::method::media_service_were_reset:
                                      this->_notifier->notify(method::lost);
                                      break;
                              }
                          })
                          .end();
}

double audio::ios_device::sample_rate() const {
    return this->_session->sample_rate();
}

std::optional<audio::format> audio::ios_device::input_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->_session->input_channel_count();

    if (sample_rate > 0.0 && ch_count > 0) {
        return audio::format({.sample_rate = sample_rate, .channel_count = ch_count});
    } else {
        return std::nullopt;
    }
}

std::optional<audio::format> audio::ios_device::output_format() const {
    auto const sample_rate = this->sample_rate();
    auto const ch_count = this->_session->output_channel_count();

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

audio::ios_device_ptr audio::ios_device::make_shared() {
    auto shared = std::shared_ptr<ios_device>(new ios_device{});
    shared->_weak_device = shared;
    return shared;
}

#endif
