//
//  yas_audio_io.mm
//

#include "yas_audio_io.h"

#include <cpp_utils/yas_stl_utils.h>

#include "yas_audio_io_kernel.h"

using namespace yas;
using namespace yas::audio;

io::io(std::optional<io_device_ptr> const &device) {
    this->_device_fetcher = observing::fetcher<device_observing_pair_t>::make_shared([this]() {
        return device_observing_pair_t{device_method::initial, this->_device};
    });

    this->set_device(device);
}

io::~io() {
    this->_uninitialize();
}

void io::_initialize() {
    if (auto const &device = this->_device) {
        auto io_core = device.value()->make_io_core();
        this->_io_core = io_core;
        io_core->set_render_handler(this->_render_handler);
        io_core->set_maximum_frames_per_slice(this->_maximum_frames);
    }
}

void io::_uninitialize() {
    this->stop();

    if (auto const &io_core = this->_io_core) {
        this->_io_core = std::nullopt;
    }
}

void io::set_device(std::optional<io_device_ptr> const &device) {
    if (this->_device != device) {
        bool const is_running = this->_is_running;

        this->_uninitialize();

        this->_device_updated_canceller = std::nullopt;

        this->_device = device;

        if (device) {
            this->_device_updated_canceller =
                device.value()
                    ->observe_io_device([this](auto const &method) {
                        switch (method) {
                            case io_device::method::updated: {
                                bool const is_running = this->is_running();

                                this->_uninitialize();
                                this->_device_fetcher->push({device_method::updated, this->device()});
                                this->_initialize();

                                if (this->_device && is_running) {
                                    this->start();
                                }
                            } break;
                            case io_device::method::lost:
                                this->set_device(std::nullopt);
                                break;
                        }
                    })
                    .end();

            this->_initialize();

            if (is_running) {
                this->start();
            }
        }

        this->_device_fetcher->push({device_method::changed, device});
    }
}

std::optional<audio::io_device_ptr> const &io::device() const {
    return this->_device;
}

bool io::is_running() const {
    return this->_is_running;
}

bool io::is_interrupting() const {
    if (auto const &device = this->_device) {
        return device.value()->is_interrupting();
    }
    return false;
}

void io::set_render_handler(std::optional<io_render_f> handler) {
    this->_render_handler = std::move(handler);

    if (auto const &io_core = this->_io_core) {
        io_core.value()->set_render_handler(this->_render_handler);
    }
}

void io::set_maximum_frames_per_slice(uint32_t const frames) {
    this->_maximum_frames = frames;

    if (auto const &io_core = this->_io_core) {
        io_core.value()->set_maximum_frames_per_slice(frames);
    }
}

uint32_t io::maximum_frames_per_slice() const {
    return this->_maximum_frames;
}

void io::start() {
    if (this->_is_running) {
        return;
    }

    this->_running_notifier->notify(running_method::will_start);

    this->_is_running = true;

    this->_start_io_core();
    this->_setup_interruption_observer();
}

void io::stop() {
    if (!this->_is_running) {
        return;
    }

    this->_dispose_interruption_observer();
    this->_stop_io_core();

    this->_is_running = false;

    this->_running_notifier->notify(running_method::did_stop);
}

observing::endable io::observe_running(std::function<void(running_method const &)> &&handler) {
    return this->_running_notifier->observe(std::move(handler));
}

observing::syncable io::observe_device(observing::caller<device_observing_pair_t>::handler_f &&handler) {
    return this->_device_fetcher->observe(std::move(handler));
}

void io::_reload() {
    bool const is_running = this->is_running();

    this->_uninitialize();
    this->_initialize();

    if (this->_device && is_running) {
        this->start();
    }
}

void io::_stop_io_core() {
    if (auto const &io_core = this->_io_core) {
        this->_io_core.value()->stop();
    }
}

void io::_start_io_core() {
    if (this->_is_running) {
        if (this->is_interrupting()) {
            return;
        }

        if (auto const &io_core = this->_io_core) {
            this->_io_core.value()->start();
        }
    }
}

void io::_setup_interruption_observer() {
    if (auto const &device = this->_device) {
        this->_interruption_canceller = device.value()
                                            ->observe_interruption([this](auto const &method) {
                                                switch (method) {
                                                    case audio::interruption_method::began:
                                                        this->_stop_io_core();
                                                        break;
                                                    case audio::interruption_method::ended:
                                                        this->_start_io_core();
                                                        break;
                                                }
                                            })
                                            .end();
    }
}

void io::_dispose_interruption_observer() {
    this->_interruption_canceller = std::nullopt;
}

audio::io_ptr io::make_shared(std::optional<io_device_ptr> const &device) {
    return std::shared_ptr<io>(new io{device});
}
