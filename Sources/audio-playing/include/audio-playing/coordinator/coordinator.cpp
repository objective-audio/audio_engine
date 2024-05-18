//
//  yas_playing_coordinator.cpp
//

#include "coordinator.h"

#include <audio-playing/common/channel_mapping.h>
#include <audio-playing/common/types.h>
#include <audio-playing/exporter/exporter.h>
#include <audio-playing/player/buffering_channel.h>
#include <audio-playing/player/buffering_element.h>
#include <audio-playing/player/buffering_resource.h>
#include <audio-playing/player/player_resource.h>
#include <audio-playing/player/reading_resource.h>
#include <audio-playing/timeline/timeline_utils.h>
#include <cpp-utils/fast_each.h>

#include <iostream>
#include <thread>

using namespace yas;
using namespace yas::playing;

coordinator::coordinator(workable_ptr const &worker, std::shared_ptr<renderer_for_coordinator> const &renderer,
                         std::shared_ptr<player_for_coordinator> const &player,
                         std::shared_ptr<exporter_for_coordinator> const &exporter)
    : _worker(worker), _renderer(renderer), _player(player), _exporter(exporter) {
    this->_exporter
        ->observe_event([this](exporter_event const &event) {
            if (event.result.is_success()) {
                if (event.result.value() == exporter_method::export_ended) {
                    if (event.range.has_value()) {
                        this->overwrite(event.range.value());
                    }
                }
            }
        })
        .end()
        ->add_to(this->_pool);

    this->_renderer->observe_format([this](auto const &) { this->_update_exporter(); }).end()->add_to(this->_pool);

    this->_worker->start();
}

void coordinator::set_timeline(proc::timeline_ptr const &timeline, std::string const &identifier) {
    this->_timeline = timeline;
    this->_identifier = identifier;

    this->_update_exporter();
    this->_player->set_identifier(identifier);
}

void coordinator::reset_timeline() {
    this->_timeline = std::nullopt;
    this->_identifier = "";

    this->_update_exporter();
    this->_player->set_identifier("");
}

void coordinator::set_timeline_format(sample_rate_t const sample_rate, audio::pcm_format const pcm_format) {
    this->_renderer->set_rendering_sample_rate(sample_rate);
    this->_renderer->set_rendering_pcm_format(pcm_format);
}

void coordinator::set_channel_mapping(playing::channel_mapping const &ch_mapping) {
    this->_player->set_channel_mapping(ch_mapping);
}

void coordinator::set_rendering(bool const is_rendering) {
    this->_renderer->set_is_rendering(is_rendering);
}

void coordinator::set_playing(bool const is_playing) {
    if (is_playing) {
        this->_renderer->set_is_rendering(true);
        std::cout << "playing::coordinator rendering started because player was played." << std::endl;
    }
    this->_player->set_playing(is_playing);
}

void coordinator::seek(frame_index_t const frame) {
    this->_player->seek(frame);
}

void coordinator::overwrite(proc::time::range const &range) {
    auto &player = this->_player;
    auto const sample_rate = this->format().sample_rate;

    proc::time::range const frags_range = timeline_utils::fragments_range(range, sample_rate);

    auto const begin_frag_idx = frags_range.frame / sample_rate;
    auto const next_frag_idx = frags_range.next_frame() / sample_rate;
    auto const length = static_cast<length_t>(next_frag_idx - begin_frag_idx);

    player->overwrite(std::nullopt, {.index = begin_frag_idx, .length = length});
}

std::string const &coordinator::identifier() const {
    return this->_identifier;
}

std::optional<proc::timeline_ptr> const &coordinator::timeline() const {
    return this->_timeline;
}

channel_mapping coordinator::channel_mapping() const {
    return this->_player->channel_mapping();
}

bool coordinator::is_playing() const {
    return this->_player->is_playing();
}

bool coordinator::is_seeking() const {
    return this->_player->is_seeking();
}

frame_index_t coordinator::current_frame() const {
    return this->_player->current_frame();
}

renderer_format const &coordinator::format() const {
    return this->_renderer->format();
}

observing::syncable coordinator::observe_format(std::function<void(renderer_format const &)> &&handler) {
    return this->_renderer->observe_format(std::move(handler));
}

observing::syncable coordinator::observe_is_playing(std::function<void(bool const &)> &&handler) {
    return this->_player->observe_is_playing(std::move(handler));
}

void coordinator::_update_exporter() {
    this->_exporter->set_timeline_container(
        timeline_container::make_shared(this->_identifier, this->_renderer->format().sample_rate, this->_timeline));
}

coordinator_ptr coordinator::make_shared(std::string const &root_path, std::shared_ptr<renderer> const &renderer) {
    auto const worker = worker::make_shared();

    auto const player = player::make_shared(
        root_path, renderer, worker, {},
        player_resource::make_shared(reading_resource::make_shared(),
                                     buffering_resource::make_shared(3, root_path, playing::make_buffering_channel)));

    auto const exporter =
        exporter::make_shared(root_path, exporter_task_queue::make_shared(2), {.timeline = 0, .fragment = 1});

    return make_shared(worker, renderer, player, exporter);
}

coordinator_ptr coordinator::make_shared(workable_ptr const &worker,
                                         std::shared_ptr<renderer_for_coordinator> const &renderer,
                                         std::shared_ptr<player_for_coordinator> const &player,
                                         std::shared_ptr<exporter_for_coordinator> const &exporter) {
    return coordinator_ptr(new coordinator{worker, renderer, player, exporter});
}
