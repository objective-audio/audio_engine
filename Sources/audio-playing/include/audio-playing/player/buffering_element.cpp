//
//  buffering_element.cpp
//

#include "buffering_element.h"

#include <audio-playing/signal_file/signal_file.h>
#include <audio-playing/signal_file/signal_file_info.h>
#include <cpp-utils/file_manager.h>

using namespace yas;
using namespace yas::playing;

buffering_element::buffering_element(audio::format const &format, sample_rate_t const frag_length)
    : _frag_length(frag_length), _buffer(format, frag_length) {
}

[[nodiscard]] buffering_element::state_t buffering_element::state() const {
    return this->_current_state;
}

[[nodiscard]] frame_index_t buffering_element::begin_frame_on_render() const {
    if (this->_current_state.load() != state_t::readable) {
        throw std::runtime_error("state is not reading.");
    }
    return this->_frag_idx * this->_frag_length;
}

[[nodiscard]] fragment_index_t buffering_element::fragment_index_on_render() const {
    if (this->_current_state.load() == state_t::initial) {
        throw std::runtime_error("state is initial.");
    }
    return this->_frag_idx;
}

[[nodiscard]] bool buffering_element::write_if_needed_on_task(path::channel const &ch_path) {
    if (this->_current_state.load() != state_t::writable) {
        return false;
    }

    if (auto const result = this->_write_on_task(ch_path)) {
        this->_current_state.store(state_t::readable);
    }

    return true;
}

void buffering_element::force_write_on_task(path::channel const &ch_path, fragment_index_t const frag_idx) {
    this->_frag_idx = frag_idx;

    if (auto const result = this->_write_on_task(ch_path)) {
        this->_current_state.store(state_t::readable);
    }
}

bool buffering_element::contains_frame_on_render(frame_index_t const frame) {
    if (this->_current_state.load() != state_t::readable) {
        return false;
    }

    auto const begin_frame = this->begin_frame_on_render();
    auto const end_frame = begin_frame + this->_frag_length;
    return begin_frame <= frame && frame < end_frame;
}

bool buffering_element::read_into_buffer_on_render(audio::pcm_buffer *out_buffer, frame_index_t const frame) {
    if (this->_current_state.load() != state_t::readable) {
        throw std::runtime_error("state is not reading.");
    }

    frame_index_t const begin_frame = this->begin_frame_on_render();
    frame_index_t const from_frame = frame - begin_frame;

    if (from_frame < 0 || this->_buffer.frame_length() <= from_frame) {
        return false;
    }

    if (begin_frame + this->_buffer.frame_length() < frame + out_buffer->frame_length()) {
        return false;
    }

    if (auto const result = out_buffer->copy_from(this->_buffer, {.from_begin_frame = static_cast<uint32_t>(from_frame),
                                                                  .length = out_buffer->frame_length()})) {
        return true;
    } else {
        return false;
    }
}

void buffering_element::advance_on_render(fragment_index_t const frag_idx) {
    if (this->_current_state.load() != state_t::readable) {
        return;
    }

    this->_frag_idx = frag_idx;
    this->_current_state.store(state_t::writable);
}

void buffering_element::overwrite_on_render() {
    if (this->_current_state.load() != state_t::readable) {
        return;
    }

    this->_current_state.store(state_t::writable);
}

audio::pcm_buffer const &buffering_element::buffer_for_test() const {
    return this->_buffer;
}

bool buffering_element::_write_on_task(path::channel const &ch_path) {
    this->_buffer.clear();

    auto const frag_idx = this->_frag_idx;

    auto const frag_path = path::fragment{ch_path, frag_idx};
    auto const paths_result = file_manager::content_paths_in_directory(frag_path.value());
    if (!paths_result) {
        if (paths_result.error() == file_manager::content_paths_error::directory_not_found) {
            return true;
        } else {
            return false;
        }
    }

    auto const &paths = paths_result.value();

    if (paths.size() == 0) {
        return true;
    }

    auto const &format = this->_buffer.format();
    std::type_info const &sample_type = yas::to_sample_type(format.pcm_format());
    if (sample_type == typeid(std::nullptr_t)) {
        return false;
    }

    std::vector<signal_file_info> infos;
    for (std::filesystem::path const &path : paths) {
        if (auto info = to_signal_file_info(path); info->sample_type == sample_type) {
            infos.emplace_back(std::move(*info));
        }
    }

    if (infos.size() == 0) {
        return true;
    }

    sample_rate_t const sample_rate = std::round(format.sample_rate());
    frame_index_t const buf_top_frame = frag_idx * sample_rate;

    for (signal_file_info const &info : infos) {
        if (auto const result = signal_file::read(info, this->_buffer, buf_top_frame); !result) {
            return false;
        }
    }

    return true;
}

buffering_element_ptr buffering_element::make_shared(audio::format const &format, sample_rate_t const frag_length) {
    return buffering_element_ptr{new buffering_element{format, frag_length}};
}
