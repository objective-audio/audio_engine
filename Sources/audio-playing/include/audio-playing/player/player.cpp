//
//  player.cpp
//

#include "player.h"

#include <audio-playing/common/channel_mapping.h>
#include <audio-playing/common/path.h>
#include <audio-playing/common/ptr.h>
#include <audio-playing/player/buffering_channel.h>
#include <audio-playing/player/buffering_element.h>
#include <audio-playing/player/buffering_resource.h>
#include <audio-playing/player/player_resource.h>
#include <audio-playing/player/player_utils.h>
#include <audio-playing/player/reading_resource.h>
#include <cpp-utils/fast_each.h>

#include <thread>

using namespace yas;
using namespace yas::playing;

player::player(std::string const &root_path, std::shared_ptr<renderer_for_player> const &renderer,
               workable_ptr const &worker, player_task_priority const &priority,
               std::shared_ptr<player_resource_for_player> const &resource)
    : _renderer(renderer), _worker(worker), _priority(priority), _resource(resource), _ch_mapping(), _identifier("") {
    using reading_state_t = reading_resource::state_t;
    using rendering_state_t = buffering_resource::rendering_state_t;
    using setup_state_t = buffering_resource::setup_state_t;

    if (priority.rendering <= priority.setup) {
        throw std::invalid_argument("invalid priority");
    }

    // setup worker

    worker->add_task(priority.setup, [resource = this->_resource] {
        auto const &reading = resource->reading();
        auto const &buffering = resource->buffering();

        auto result = worker::task_result::unprocessed;

        if (reading->state() == reading_state_t::creating) {
            reading->create_buffer_on_task();
            std::this_thread::yield();
            result = worker::task_result::processed;
            std::this_thread::yield();
        }

        if (buffering->setup_state() == setup_state_t::creating) {
            buffering->create_buffer_on_task();
            std::this_thread::yield();
            result = worker::task_result::processed;
            std::this_thread::yield();
        }

        return result;
    });

    worker->add_task(priority.rendering, [buffering = this->_resource->buffering()] {
#warning 細かく処理を分ける&他のステートを見て途中でやめる
        switch (buffering->rendering_state()) {
            case rendering_state_t::waiting:
                return worker::task_result::unprocessed;
            case rendering_state_t::all_writing:
                buffering->write_all_elements_on_task();
                return worker::task_result::processed;
            case rendering_state_t::advancing:
                if (buffering->write_elements_if_needed_on_task()) {
                    return worker::task_result::processed;
                } else {
                    return worker::task_result::unprocessed;
                }
        }
    });

    // setup renderer

    player_resource::overwrite_requests_f overwrite_requests_handler =
        [buffering = this->_resource->buffering()](player_resource::overwrite_requests_t const &requests) {
            for (auto const &request : requests) {
                buffering->overwrite_element_on_render(request);
            }
        };

    this->_renderer->set_rendering_handler([resource = this->_resource,
                                            overwrite_requests_handler = std::move(overwrite_requests_handler)](
                                               audio::pcm_buffer *const out_buffer) {
        auto const &reading = resource->reading();
        auto const &buffering = resource->buffering();

        auto const &out_format = out_buffer->format();
        auto const sample_rate = static_cast<sample_rate_t>(std::round(out_format.sample_rate()));
        auto const pcm_format = out_format.pcm_format();
        auto const out_length = out_buffer->frame_length();
        auto const out_ch_count = out_format.channel_count();

        if (out_format.is_interleaved()) {
            throw std::invalid_argument("out_buffer is not non-interleaved.");
        }

        // reading_resourceのセットアップ

        switch (reading->state()) {
            case reading_state_t::initial:
                // 初期状態なのでバッファ生成開始
                reading->set_creating_on_render(sample_rate, pcm_format, out_length);
                return;
            case reading_state_t::creating:
                // task側で生成中
                return;
            case reading_state_t::rendering:
                // バッファ生成済み
                break;
        }

        // 生成済みのreadingバッファを作り直すかチェック
        if (reading->needs_create_on_render(sample_rate, pcm_format, out_length)) {
            // バッファを再生成
            reading->set_creating_on_render(sample_rate, pcm_format, out_length);
            return;
        }

        // buffering_resourceのセットアップ

        switch (buffering->setup_state()) {
            case setup_state_t::initial:
                // 初期状態なのでバッファ生成開始
                buffering->set_creating_on_render(sample_rate, pcm_format, out_ch_count);
                return;
            case setup_state_t::creating:
                // task側で生成中
                return;
            case setup_state_t::rendering:
                // バッファ生成済み
                break;
        }

        // 生成済みのbufferingバッファを作り直すかチェック
        if (buffering->needs_create_on_render(sample_rate, pcm_format, out_ch_count)) {
            // バッファの再生成
            buffering->set_creating_on_render(sample_rate, pcm_format, out_ch_count);
            return;
        }

        // bufferingバッファへの書き込み
        auto const rendering_state = buffering->rendering_state();
        switch (rendering_state) {
            case rendering_state_t::all_writing:
                // task側で書き込み中
                return;
            case rendering_state_t::waiting:
                // 書き込み待機状態
                [[fallthrough]];
            case rendering_state_t::advancing: {
                // 全バッファ書き込み済み
                auto const seek_frame = resource->pull_seek_frame_on_render();
                bool const needs_all_writing = buffering->needs_all_writing_on_render();

                if (rendering_state == rendering_state_t::waiting || seek_frame.has_value() || needs_all_writing) {
                    // 全バッファ再書き込み開始
                    resource->reset_overwrite_requests_on_render();
                    auto const frame = seek_frame.has_value() ? seek_frame.value() : resource->current_frame();
                    if (seek_frame.has_value()) {
                        resource->set_current_frame_on_render(frame);
                    }
                    buffering->set_all_writing_on_render(frame);
                    return;
                }
            } break;
        }

        // bufferingの要素の上書き
        resource->perform_overwrite_requests_on_render(overwrite_requests_handler);

        // 再生中でなければ終了
        if (!resource->is_playing_on_render()) {
            return;
        }

        // 以下レンダリング

        audio::pcm_buffer *reading_buffer = reading->buffer_on_render();
        if (!reading_buffer) {
            return;
        }

        frame_index_t const begin_frame = resource->current_frame();
        frame_index_t current_frame = begin_frame;
        frame_index_t const next_frame = current_frame + out_length;
        uint32_t const frag_length = buffering->fragment_length_on_render();

        while (current_frame < next_frame) {
            auto const proc_length = player_utils::process_length(current_frame, next_frame, frag_length);
            uint32_t const to_frame = uint32_t(current_frame - begin_frame);

            bool read_failed = false;

            auto each = make_fast_each(out_format.channel_count());
            while (yas_each_next(each)) {
                auto const &idx = yas_each_index(each);

                if (buffering->channel_count_on_render() <= idx) {
                    break;
                }

                reading_buffer->clear();
                reading_buffer->set_frame_length(proc_length);

                if (!buffering->read_into_buffer_on_render(reading_buffer, idx, current_frame)) {
                    read_failed = true;
                    break;
                }

                out_buffer->copy_channel_from(*reading_buffer,
                                              {.to_channel = idx, .to_begin_frame = to_frame, .length = proc_length});
            }

            if (read_failed) {
                break;
            }

            if (auto const frag_idx = player_utils::advancing_fragment_index(current_frame, proc_length, frag_length);
                frag_idx.has_value()) {
                buffering->advance_on_render(frag_idx.value());
            }

            current_frame += proc_length;

            resource->set_current_frame_on_render(current_frame);
        }
    });

    this->_resource->buffering()->set_identifier_request_on_main(this->_identifier);
    this->_resource->buffering()->set_channel_mapping_request_on_main(this->_ch_mapping);

    // setup observing

    this->_is_playing->observe([this](bool const &is_playing) { this->_resource->set_playing_on_main(is_playing); })
        .sync()
        ->add_to(this->_pool);
}

void player::set_identifier(std::string const &identifier) {
    this->_identifier = identifier;
    this->_resource->buffering()->set_identifier_request_on_main(identifier);
}

void player::set_channel_mapping(playing::channel_mapping const &ch_mapping) {
    this->_ch_mapping = ch_mapping;
    this->_resource->buffering()->set_channel_mapping_request_on_main(ch_mapping);
}

void player::set_playing(bool const is_playing) {
    this->_is_playing->set_value(is_playing);
}

void player::seek(frame_index_t const frame) {
    this->_resource->seek_on_main(frame);
}

void player::overwrite(std::optional<channel_index_t> const file_ch_idx, fragment_range const frag_range) {
    this->_resource->add_overwrite_request_on_main({.file_channel_index = file_ch_idx, .fragment_range = frag_range});
}

std::string const &player::identifier() const {
    return this->_identifier;
}

channel_mapping player::channel_mapping() const {
    return this->_ch_mapping;
}

bool player::is_playing() const {
    return this->_is_playing->value();
}

bool player::is_seeking() const {
    return this->_resource->is_seeking_on_main();
}

frame_index_t player::current_frame() const {
    return this->_resource->current_frame();
}

observing::syncable player::observe_is_playing(std::function<void(bool const &)> &&handler) {
    return this->_is_playing->observe(std::move(handler));
}

player_ptr player::make_shared(std::string const &root_path, std::shared_ptr<renderer_for_player> const &renderer,
                               workable_ptr const &worker, player_task_priority const &priority,
                               std::shared_ptr<player_resource_for_player> const &resource) {
    return player_ptr(new player{root_path, renderer, worker, priority, resource});
}
