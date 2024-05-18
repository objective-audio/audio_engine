//
//  buffering_resource.cpp
//

#include "buffering_resource.h"

#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/channel_mapping.h>
#include <audio-playing/player/buffering_channel.h>
#include <audio-playing/player/buffering_element.h>
#include <audio-playing/player/player_utils.h>
#include <audio-playing/signal_file/signal_file.h>
#include <audio-playing/signal_file/signal_file_info.h>
#include <cpp-utils/fast_each.h>
#include <cpp-utils/file_manager.h>
#include <cpp-utils/result.h>

#include <mutex>
#include <thread>

using namespace yas;
using namespace yas::playing;

buffering_resource::buffering_resource(std::size_t const element_count, std::string const &root_path,
                                       make_channel_f &&make_channel_handler)
    : _element_count(element_count), _root_path(root_path), _make_channel_handler(make_channel_handler), _ch_mapping() {
}

std::size_t buffering_resource::element_count() const {
    return this->_element_count;
}

buffering_resource::setup_state_t buffering_resource::setup_state() const {
    return this->_setup_state.load();
}

buffering_resource::rendering_state_t buffering_resource::rendering_state() const {
    return this->_rendering_state.load();
}

std::size_t buffering_resource::channel_count_on_render() const {
    return this->_ch_count;
}

sample_rate_t buffering_resource::fragment_length_on_render() const {
    return this->_frag_length;
}

void buffering_resource::set_creating_on_render(sample_rate_t const sample_rate, audio::pcm_format const &pcm_format,
                                                uint32_t const ch_count) {
    if (auto const state = this->_setup_state.load(); state == setup_state_t::creating) {
        throw std::runtime_error("state (" + to_string(state) + ") is already creating.");
    }

    this->_sample_rate = sample_rate;
    this->_frag_length = round(sample_rate);
    this->_pcm_format = pcm_format;
    this->_ch_count = ch_count;
    this->_setup_state.store(setup_state_t::creating);
}

bool buffering_resource::needs_create_on_render(sample_rate_t const sample_rate, audio::pcm_format const &pcm_format,
                                                uint32_t const ch_count) {
    if (auto const state = this->_setup_state.load(); state != setup_state_t::rendering) {
        throw std::runtime_error("state (" + to_string(state) + ") is not rendering.");
    }

    if (this->_sample_rate != sample_rate) {
        return true;
    }

    if (this->_pcm_format != pcm_format) {
        return true;
    }

    if (this->_ch_count != ch_count) {
        return true;
    }

    return false;
}

void buffering_resource::create_buffer_on_task() {
    if (auto const state = this->_setup_state.load(); state != setup_state_t::creating) {
        throw std::runtime_error("state (" + to_string(state) + ") is not creating.");
    }

    this->_format = std::nullopt;
    this->_tl_path = std::nullopt;
    this->_channels.clear();

    std::this_thread::yield();

    if (this->_sample_rate == 0) {
        throw std::runtime_error("sample_rate is zero.");
    }

    if (this->_frag_length == 0) {
        throw std::runtime_error("frag_length is zero.");
    }

    if (this->_ch_count == 0) {
        throw std::runtime_error("ch_count is zero.");
    }

    audio::format const format{{.sample_rate = static_cast<double>(this->_sample_rate),
                                .pcm_format = this->_pcm_format,
                                .interleaved = false,
                                .channel_count = 1}};

    this->_format = format;

    std::this_thread::yield();

    auto ch_each = make_fast_each(this->_ch_count);
    while (yas_each_next(ch_each)) {
        this->_channels.emplace_back(this->_make_channel_handler(this->_element_count, format, this->_sample_rate));

        std::this_thread::yield();
    }

    this->_rendering_state.store(rendering_state_t::waiting);

    std::this_thread::yield();

    this->_setup_state.store(setup_state_t::rendering);

    std::this_thread::yield();
}

void buffering_resource::set_all_writing_on_render(frame_index_t const frame) {
    if (auto const state = this->_rendering_state.load(); state == rendering_state_t::all_writing) {
        throw std::runtime_error("state (" + to_string(state) + ") is already all_writing.");
    }

    this->_all_writing_frame = frame;

    this->_rendering_state.store(rendering_state_t::all_writing);
}

void buffering_resource::write_all_elements_on_task() {
    if (auto const state = this->_rendering_state.load(); state != rendering_state_t::all_writing) {
        throw std::runtime_error("state (" + to_string(state) + ") is not all_writing.");
    }

    if (auto ch_mapping = this->_pull_ch_mapping_request_on_task(); ch_mapping.has_value()) {
        this->_ch_mapping = std::move(ch_mapping.value());
    }

    std::this_thread::yield();

    if (auto identifier = this->_pull_identifier_request_on_task(); identifier.has_value()) {
        this->_identifier = std::move(identifier.value());
    }

    std::this_thread::yield();

    this->_tl_path = path::timeline{.root_path = this->_root_path,
                                    .identifier = this->_identifier,
                                    .sample_rate = static_cast<sample_rate_t>(this->_sample_rate)};

    std::this_thread::yield();

    auto const top_frag_idx = player_utils::top_fragment_idx(this->_frag_length, this->_all_writing_frame);
    if (!top_frag_idx.has_value()) {
        throw std::runtime_error("sample_rate is empty.");
    }

    channel_index_t ch_idx = 0;
    auto const ch_count = this->_channels.size();
    for (auto const &channel : this->_channels) {
        path::channel const ch_path{*this->_tl_path, this->_ch_mapping.file_index(ch_idx, ch_count).value()};
        channel->write_all_elements_on_task(ch_path, top_frag_idx.value());

        ++ch_idx;

        std::this_thread::yield();
    }

    std::this_thread::yield();

    this->_rendering_state.store(rendering_state_t::advancing);

    std::this_thread::yield();
}

void buffering_resource::advance_on_render(fragment_index_t const frag_idx) {
    if (auto const state = this->_rendering_state.load(); state != rendering_state_t::advancing) {
        throw std::runtime_error("state (" + to_string(state) + ") is not advancing.");
    }

    for (auto const &channel : this->_channels) {
        channel->advance_on_render(frag_idx);
    }
}

bool buffering_resource::write_elements_if_needed_on_task() {
    if (auto const state = this->_rendering_state.load(); state != rendering_state_t::advancing) {
        // メソッドが呼ばれるまでにrenderスレッドでrendering_stateが変更される可能性があるので単に中断する
        return false;
    }

    bool is_loaded = false;

    for (auto const &channel : this->_channels) {
        if (channel->write_elements_if_needed_on_task()) {
            is_loaded = true;
        }

        std::this_thread::yield();
    }

    return is_loaded;
}

void buffering_resource::overwrite_element_on_render(element_address const &address) {
    if (auto const state = this->_rendering_state.load(); state != rendering_state_t::advancing) {
        throw std::runtime_error("state (" + to_string(state) + ") is not advancing.");
    }

    if (address.file_channel_index.has_value()) {
        if (auto const out_ch_idx =
                this->_ch_mapping.out_index(address.file_channel_index.value(), this->_channels.size());
            out_ch_idx.has_value()) {
            this->_channels.at(out_ch_idx.value())->overwrite_element_on_render(address.fragment_range);
        }
    } else {
        for (auto const &channel : this->_channels) {
            channel->overwrite_element_on_render(address.fragment_range);
        }
    }
}

bool buffering_resource::needs_all_writing_on_render() const {
    if (auto const state = this->_rendering_state.load(); true) {
        if (state != rendering_state_t::waiting && state != rendering_state_t::advancing) {
            throw std::runtime_error("state (" + to_string(state) + ") is not waiting or advanding.");
        }
    }

    if (auto lock = std::unique_lock<std::mutex>(this->_request_mutex, std::try_to_lock); lock.owns_lock()) {
        return this->_ch_mapping_request.has_value() || this->_identifier_request.has_value();
    }
    return false;
}

void buffering_resource::set_channel_mapping_request_on_main(channel_mapping const &ch_mapping) {
    std::lock_guard<std::mutex> lock(this->_request_mutex);
    this->_ch_mapping_request = ch_mapping;
}

void buffering_resource::set_identifier_request_on_main(std::string const &identifier) {
    std::lock_guard<std::mutex> lock(this->_request_mutex);
    this->_identifier_request = identifier;
}

bool buffering_resource::read_into_buffer_on_render(audio::pcm_buffer *out_buffer, channel_index_t const ch_idx,
                                                    frame_index_t const frame) {
    if (auto const state = this->_rendering_state.load(); state != rendering_state_t::advancing) {
        throw std::runtime_error("state (" + to_string(state) + ") is not advancing.");
    }

    if (this->_channels.size() <= ch_idx) {
        return false;
    }

    return this->_channels.at(ch_idx)->read_into_buffer_on_render(out_buffer, frame);
}

std::optional<channel_mapping> buffering_resource::_pull_ch_mapping_request_on_task() {
    if (auto lock = std::unique_lock<std::mutex>(this->_request_mutex, std::try_to_lock); lock.owns_lock()) {
        auto ch_mapping = std::move(this->_ch_mapping_request);
        this->_ch_mapping_request = std::nullopt;
        return ch_mapping;
    }
    return std::nullopt;
}

std::optional<std::string> buffering_resource::_pull_identifier_request_on_task() {
    if (auto lock = std::unique_lock<std::mutex>(this->_request_mutex, std::try_to_lock); lock.owns_lock()) {
        auto identifier = std::move(this->_identifier_request);
        this->_identifier_request = std::nullopt;
        return identifier;
    }
    return std::nullopt;
}

buffering_resource_ptr buffering_resource::make_shared(std::size_t const element_count, std::string const &root_path,

                                                       make_channel_f &&make_channel_handler) {
    return buffering_resource_ptr{new buffering_resource{element_count, root_path, std::move(make_channel_handler)}};
}

frame_index_t buffering_resource::all_writing_frame_for_test() const {
    return this->_all_writing_frame;
}

channel_mapping const &buffering_resource::ch_mapping_for_test() const {
    return this->_ch_mapping;
}

std::string const &buffering_resource::identifier_for_test() const {
    return this->_identifier;
}
