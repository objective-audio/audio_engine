//
//  yas_audio_io.mm
//

#include "yas_audio_io.h"

#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_io_kernel.h"

using namespace yas;

audio::io::io() = default;

audio::io::~io() {
    this->_uninitialize();
}

void audio::io::_initialize() {
    if (this->_device && this->_io_core) {
        this->_io_core.value()->initialize();
    }
}

void audio::io::_uninitialize() {
    this->stop();

    if (auto const &io_core = this->_io_core) {
        io_core.value()->uninitialize();
    }
}

void audio::io::set_device(std::optional<io_device_ptr> const &device) {
    if (this->_device != device) {
        bool const is_running = this->_is_running;

        this->_uninitialize();

        this->_observer = std::nullopt;
        this->_io_core = std::nullopt;

        this->_device = device;

        if (device) {
            auto io_core = device.value()->make_io_core();

            io_core->set_render_handler(this->_render_handler);
            io_core->set_maximum_frames_per_slice(this->_maximum_frames);

            this->_observer = device.value()
                                  ->io_device_chain()
                                  .perform([weak_io = this->_weak_io](auto const &method) {
                                      if (auto const io = weak_io.lock()) {
                                          switch (method) {
                                              case io_device::method::updated:
                                                  io->_reload();
                                                  break;
                                              case io_device::method::lost:
                                                  io->_uninitialize();
                                                  break;
                                          }
                                      }
                                  })
                                  .end();

            this->_io_core = io_core;

            this->_initialize();

            if (is_running) {
                this->start();
            }
        }
    }
}

std::optional<audio::io_device_ptr> const &audio::io::device() const {
    return this->_device;
}

bool audio::io::is_running() const {
    return this->_is_running;
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

bool audio::io::start() {
    if (this->_is_running) {
        return true;
    }

    if (this->_io_core) {
        if (bool result = this->_io_core.value()->start()) {
            this->_is_running = true;
        }
    }
    return false;
}

void audio::io::stop() {
    if (!this->_is_running) {
        return;
    }

    this->_is_running = false;

    if (this->_io_core) {
        this->_io_core.value()->stop();
    }
}

std::optional<audio::pcm_buffer_ptr> const &audio::io::input_buffer_on_render() const {
    if (auto const &io_core = this->_io_core) {
        return io_core.value()->input_buffer_on_render();
    } else {
        static std::optional<audio::pcm_buffer_ptr> _null_buffer = std::nullopt;
        return _null_buffer;
    }
}

std::optional<audio::time_ptr> const &audio::io::input_time_on_render() const {
    if (auto const &io_core = this->_io_core) {
        return io_core.value()->input_time_on_render();
    } else {
        static std::optional<audio::time_ptr> _null_time = std::nullopt;
        return _null_time;
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

audio::io_ptr audio::io::make_shared(std::optional<io_device_ptr> const &device) {
    auto shared = std::shared_ptr<io>(new io{});
    shared->_weak_io = shared;
    shared->set_device(device);
    return shared;
}
