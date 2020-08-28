//
//  yas_audio_io.mm
//

#include "yas_audio_io.h"

#include <cpp_utils/yas_stl_utils.h>

#include "yas_audio_io_kernel.h"

using namespace yas;

audio::io::io(std::optional<io_device_ptr> const &device) {
    this->_running_notifier = chaining::notifier<running_method>::make_shared();

    this->_device_fetcher = chaining::fetcher<device_chaining_pair_t>::make_shared([this]() {
        return device_chaining_pair_t{device_method::initial, this->_device};
    });

    this->set_device(device);
}

audio::io::~io() {
    this->_uninitialize();
}

void audio::io::_initialize() {
    if (auto const &device = this->_device) {
        auto io_core = device.value()->make_io_core();
        this->_io_core = io_core;
        io_core->set_render_handler(this->_render_handler);
        io_core->set_maximum_frames_per_slice(this->_maximum_frames);
        io_core->initialize();
    }
}

void audio::io::_uninitialize() {
    this->stop();

    if (auto const &io_core = this->_io_core) {
        io_core.value()->uninitialize();
        this->_io_core = std::nullopt;
    }
}

void audio::io::set_device(std::optional<io_device_ptr> const &device) {
    if (this->_device != device) {
        bool const is_running = this->_is_running;

        this->_uninitialize();

        this->_device_updated_observer = std::nullopt;

        this->_device = device;

        if (device) {
            this->_device_updated_observer =
                device.value()
                    ->io_device_chain()
                    .perform([this](auto const &method) {
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

std::optional<audio::io_device_ptr> const &audio::io::device() const {
    return this->_device;
}

bool audio::io::is_running() const {
    return this->_is_running;
}

bool audio::io::is_interrupting() const {
    if (auto const &device = this->_device) {
        return device.value()->is_interrupting();
    }
    return false;
}

void audio::io::set_render_handler(std::optional<io_render_f> handler) {
    this->_render_handler = std::move(handler);

    if (auto const &io_core = this->_io_core) {
        io_core.value()->set_render_handler(this->_render_handler);
    }
}

void audio::io::set_maximum_frames_per_slice(uint32_t const frames) {
    this->_maximum_frames = frames;

    if (auto const &io_core = this->_io_core) {
        io_core.value()->set_maximum_frames_per_slice(frames);
    }
}

uint32_t audio::io::maximum_frames_per_slice() const {
    return this->_maximum_frames;
}

void audio::io::start() {
    if (this->_is_running) {
        return;
    }

    this->_running_notifier->notify(running_method::will_start);

    this->_is_running = true;

    this->_start_io_core();
    this->_setup_interruption_observer();
}

void audio::io::stop() {
    if (!this->_is_running) {
        return;
    }

    this->_dispose_interruption_observer();
    this->_stop_io_core();

    this->_is_running = false;

    this->_running_notifier->notify(running_method::did_stop);
}

chaining::chain_unsync_t<audio::io::running_method> audio::io::running_chain() const {
    return this->_running_notifier->chain();
}

chaining::chain_sync_t<audio::io::device_chaining_pair_t> audio::io::device_chain() const {
    return this->_device_fetcher->chain();
}

audio::pcm_buffer const *audio::io::input_buffer_on_render() const {
    if (auto const &io_core = this->_io_core) {
        return io_core.value()->input_buffer_on_render();
    } else {
        return nullptr;
    }
}

void audio::io::_reload() {
    bool const is_running = this->is_running();

    this->_uninitialize();
    this->_initialize();

    if (this->_device && is_running) {
        this->start();
    }
}

void audio::io::_stop_io_core() {
    if (auto const &io_core = this->_io_core) {
        this->_io_core.value()->stop();
    }
}

void audio::io::_start_io_core() {
    if (this->_is_running) {
        if (this->is_interrupting()) {
            return;
        }

        if (auto const &io_core = this->_io_core) {
            this->_io_core.value()->start();
        }
    }
}

void audio::io::_setup_interruption_observer() {
    if (auto chain = this->_interruption_chain()) {
        this->_interruption_observer = chain.value()
                                           .perform([this](auto const &method) {
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

void audio::io::_dispose_interruption_observer() {
    this->_interruption_observer = std::nullopt;
}

std::optional<chaining::chain_unsync_t<audio::interruption_method>> audio::io::_interruption_chain() const {
    if (auto const &device = this->_device) {
        return device.value()->interruption_chain();
    }
    return std::nullopt;
}

audio::io_ptr audio::io::make_shared(std::optional<io_device_ptr> const &device) {
    return std::shared_ptr<io>(new io{device});
}
