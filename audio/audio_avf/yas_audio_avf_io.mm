//
//  yas_audio_avf_io.mm
//

#include "yas_audio_avf_io.h"

#if TARGET_OS_IPHONE

#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_io_kernel.h"

using namespace yas;

#pragma mark -

audio::avf_io::avf_io() = default;

audio::avf_io::~avf_io() {
    this->_uninitialize();
}

void audio::avf_io::_initialize() {
    if (this->_device && this->_io_core) {
        this->_io_core.value()->initialize();
    }
}

void audio::avf_io::_uninitialize() {
    this->stop();

    if (auto const &io_core = this->_io_core) {
        io_core.value()->uninitialize();
    }
}

void audio::avf_io::set_device(std::optional<avf_device_ptr> const &device) {
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

            this->_observer = io_core->chain()
                                  .perform([weak_io = this->_weak_io](auto const &method) {
                                      if (auto const avf_io = weak_io.lock()) {
                                          switch (method) {
                                              case io_core::method::updated:
                                                  avf_io->_reload();
                                                  break;
                                              case io_core::method::lost:
                                                  avf_io->_uninitialize();
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

std::optional<audio::avf_device_ptr> const &audio::avf_io::device() const {
    return this->_device;
}

bool audio::avf_io::is_running() const {
    return this->_is_running;
}

void audio::avf_io::set_render_handler(io_render_f handler) {
    this->_render_handler = std::move(handler);

    if (auto const &io_core = this->_io_core) {
        io_core.value()->set_render_handler(this->_render_handler);
    }
}

void audio::avf_io::set_maximum_frames_per_slice(uint32_t const frames) {
    this->_maximum_frames = frames;

    if (auto const &io_core = this->_io_core) {
        io_core.value()->set_maximum_frames_per_slice(frames);
    }
}

uint32_t audio::avf_io::maximum_frames_per_slice() const {
    return this->_maximum_frames;
}

bool audio::avf_io::start() {
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

void audio::avf_io::stop() {
    if (!this->_is_running) {
        return;
    }

    this->_is_running = false;

    if (this->_io_core) {
        this->_io_core.value()->stop();
    }
}

std::optional<audio::pcm_buffer_ptr> const &audio::avf_io::input_buffer_on_render() const {
    if (auto const &io_core = this->_io_core) {
        return io_core.value()->input_buffer_on_render();
    } else {
        static std::optional<audio::pcm_buffer_ptr> _null_buffer = std::nullopt;
        return _null_buffer;
    }
}

std::optional<audio::time_ptr> const &audio::avf_io::input_time_on_render() const {
    if (auto const &io_core = this->_io_core) {
        return io_core.value()->input_time_on_render();
    } else {
        static std::optional<audio::time_ptr> _null_time = std::nullopt;
        return _null_time;
    }
}

void audio::avf_io::_reload() {
    bool const is_running = this->is_running();

    this->_uninitialize();
    this->_initialize();

    if (this->_device && is_running) {
        this->start();
    }
}

audio::avf_io_ptr audio::avf_io::make_shared(std::optional<avf_device_ptr> const &device) {
    auto shared = std::shared_ptr<avf_io>(new avf_io{});
    shared->_weak_io = shared;
    shared->set_device(device);
    return shared;
}

#endif
