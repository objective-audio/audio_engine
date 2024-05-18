//
//  yas_playing_reading.cpp
//

#include "reading_resource.h"

#include <thread>

using namespace yas;
using namespace yas::playing;

reading_resource::reading_resource() {
}

reading_resource::state_t reading_resource::state() const {
    return this->_current_state.load();
}

audio::pcm_buffer *reading_resource::buffer_on_render() {
    if (this->_current_state != state_t::rendering) {
        throw std::runtime_error("state is not rendering");
    }

    return this->_buffer.get();
}

bool reading_resource::needs_create_on_render(sample_rate_t const sample_rate, audio::pcm_format const pcm_format,
                                              uint32_t const length) const {
    if (this->_current_state != state_t::rendering) {
        throw std::runtime_error("state is not rendering");
    }

    return this->_buffer->format().sample_rate() != sample_rate || this->_buffer->frame_capacity() < length;
}

void reading_resource::set_creating_on_render(sample_rate_t const sample_rate, audio::pcm_format const pcm_format,
                                              uint32_t const length) {
    if (this->_current_state == state_t::creating) {
        throw std::runtime_error("state is already creating.");
    }

    if (length == 0) {
        throw std::invalid_argument("length is zero.");
    }

    this->_sample_rate = sample_rate;
    this->_pcm_format = pcm_format;
    this->_length = length;

    this->_current_state.store(state_t::creating);
}

void reading_resource::create_buffer_on_task() {
    if (this->_current_state != state_t::creating) {
        throw std::runtime_error("state is not creating.");
    }

    this->_buffer = nullptr;

    std::this_thread::yield();

    if (this->_sample_rate == 0) {
        throw std::runtime_error("sample_rate is zero.");
    }

    if (this->_length == 0) {
        throw std::runtime_error("length is zero.");
    }

    audio::format const format{{.sample_rate = static_cast<double>(this->_sample_rate),
                                .pcm_format = this->_pcm_format,
                                .interleaved = false,
                                .channel_count = 1}};

    this->_buffer = std::make_shared<audio::pcm_buffer>(format, this->_length);
    this->_sample_rate = 0;
    this->_length = 0;

    this->_current_state.store(state_t::rendering);

    std::this_thread::yield();
}

reading_resource_ptr reading_resource::make_shared() {
    return reading_resource_ptr(new reading_resource{});
}
