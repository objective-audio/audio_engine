//
//  buffering_channel.cpp
//

#include "buffering_channel.h"

#include <audio-playing/player/buffering_element.h>
#include <cpp-utils/fast_each.h>

#include <thread>

using namespace yas;
using namespace yas::playing;

buffering_channel::buffering_channel(std::vector<std::shared_ptr<buffering_element_for_buffering_channel>> &&elements)
    : _elements(std::move(elements)) {
}

void buffering_channel::write_all_elements_on_task(path::channel const &ch_path, fragment_index_t const top_frag_idx) {
    this->_ch_path = ch_path;

    fragment_index_t element_frag_idx = top_frag_idx;
    for (auto &element : this->_elements) {
        element->force_write_on_task(ch_path, element_frag_idx);
        ++element_frag_idx;

        std::this_thread::yield();
    }
}

bool buffering_channel::write_elements_if_needed_on_task() {
    bool is_written = false;

    for (auto &element : this->_elements) {
        if (element->write_if_needed_on_task(this->_ch_path.value())) {
            is_written = true;
        }
    }

    return is_written;
}

void buffering_channel::advance_on_render(fragment_index_t const frag_idx) {
    for (auto const &element : this->_elements) {
        if (element->fragment_index_on_render() == frag_idx) {
            element->advance_on_render(frag_idx + this->_elements.size());
        }
    }
}

void buffering_channel::overwrite_element_on_render(fragment_range const range) {
    for (auto const &element : this->_elements) {
        auto const frag_idx = element->fragment_index_on_render();
        if (range.contains(frag_idx)) {
            element->overwrite_on_render();
        }
    }
}

bool buffering_channel::read_into_buffer_on_render(audio::pcm_buffer *out_buffer, frame_index_t const frame) {
    for (auto const &element : this->_elements) {
        if (element->contains_frame_on_render(frame)) {
            return element->read_into_buffer_on_render(out_buffer, frame);
        }
    }

    return false;
}

std::vector<std::shared_ptr<buffering_element_for_buffering_channel>> const &buffering_channel::elements_for_test()
    const {
    return this->_elements;
}

buffering_channel_ptr buffering_channel::make_shared(
    std::vector<std::shared_ptr<buffering_element_for_buffering_channel>> &&elements) {
    return buffering_channel_ptr{new buffering_channel{std::move(elements)}};
}

buffering_channel_ptr playing::make_buffering_channel(std::size_t const element_count, audio::format const &format,
                                                      sample_rate_t const frag_length) {
    std::vector<std::shared_ptr<buffering_element_for_buffering_channel>> elements;
    elements.reserve(element_count);

    auto element_each = make_fast_each(element_count);
    while (yas_each_next(element_each)) {
        elements.emplace_back(buffering_element::make_shared(format, frag_length));
        std::this_thread::yield();
    }

    return buffering_channel::make_shared(std::move(elements));
}
