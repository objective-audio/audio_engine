//
//  timeline.cpp
//

#include "timeline.h"

#include <audio-processing/stream/stream.h>
#include <audio-processing/sync_source/sync_source.h>
#include <audio-processing/timeline/timeline_utils.h>
#include <audio-processing/track/track.h>

using namespace yas;
using namespace yas::proc;

#pragma mark - timeline

proc::timeline_ptr timeline::make_shared() {
    return make_shared({});
}

proc::timeline_ptr timeline::make_shared(track_map_t &&tracks) {
    return timeline_ptr(new timeline{std::move(tracks)});
}

timeline::timeline(track_map_t &&tracks) : _tracks_holder(tracks_holder_t::make_shared(std::move(tracks))) {
    this->_fetcher = observing::fetcher<timeline_event>::make_shared([this] {
        return timeline_event{.type = timeline_event_type::any, .tracks = this->_tracks_holder->elements()};
    });

    this->_tracks_canceller = this->_tracks_holder
                                  ->observe([this](tracks_holder_t::event const &tracks_event) {
                                      this->_push_timeline_event({.type = to_timeline_event_type(tracks_event.type),
                                                                  .tracks = tracks_event.elements,
                                                                  .inserted = tracks_event.inserted,
                                                                  .erased = tracks_event.erased,
                                                                  .index = tracks_event.key});
                                  })
                                  .end();

    this->_observe_all_tracks();
}

timeline::track_map_t const &timeline::tracks() const {
    return this->_tracks_holder->elements();
}

void timeline::replace_tracks(track_map_t &&tracks) {
    this->_track_cancellers.clear();

    this->_tracks_holder->replace(std::move(tracks));

    this->_observe_all_tracks();
}

bool timeline::insert_track(track_index_t const trk_idx, proc::track_ptr const &track) {
    auto const &tracks_holder = this->_tracks_holder;
    if (!tracks_holder->contains(trk_idx)) {
        tracks_holder->insert_or_replace(trk_idx, track);
        this->_observe_track(trk_idx);
        return true;
    } else {
        return false;
    }
}

void timeline::erase_track(track_index_t const trk_idx) {
    this->_track_cancellers.erase(trk_idx);
    this->_tracks_holder->erase(trk_idx);
}

void timeline::erase_all_tracks() {
    this->_track_cancellers.clear();
    this->_tracks_holder->clear();
}

std::size_t timeline::track_count() const {
    return this->_tracks_holder->size();
}

bool timeline::has_track(track_index_t const idx) const {
    return this->_tracks_holder->contains(idx);
}

proc::track_ptr const &timeline::track(track_index_t const trk_idx) const {
    return this->_tracks_holder->at(trk_idx);
}

std::optional<proc::time::range> timeline::total_range() const {
    return proc::total_range(this->_tracks_holder->elements());
}

proc::timeline_ptr timeline::copy() const {
    return timeline::make_shared(proc::copy_tracks(this->_tracks_holder->elements()));
}

void timeline::process(time::range const &time_range, stream &stream) {
    for (auto &track_pair : this->_tracks_holder->elements()) {
        track_pair.second->process(time_range, stream);
    }
}

void timeline::process(time::range const &range, sync_source const &sync_src, process_f const &handler) {
    this->_process_continuously(
        range, sync_src,
        [&handler](time::range const &range, stream const &stream, std::optional<track_index_t> const &trk_idx) {
            if (!trk_idx.has_value()) {
                return handler(range, stream);
            }
            return continuation::keep;
        });
}

void timeline::process(time::range const &range, sync_source const &sync_src, process_track_f const &handler) {
    this->_process_continuously(range, sync_src, handler);
}

observing::syncable timeline::observe(observing_handler_f &&handler) {
    return this->_fetcher->observe(std::move(handler));
}

void timeline::_process_continuously(time::range const &range, sync_source const &sync_src,
                                     process_track_f const &handler) {
    frame_index_t frame = range.frame;

    while (frame < range.next_frame()) {
        frame_index_t const sync_next_frame = frame + sync_src.slice_length;
        frame_index_t const &end_next_frame = range.next_frame();

        stream stream{sync_src};

        time::range const current_range = time::range{
            frame,
            static_cast<length_t>(sync_next_frame < end_next_frame ? sync_next_frame - frame : end_next_frame - frame)};

        if (this->_process_tracks(current_range, stream, handler) == continuation::abort) {
            break;
        }

        if (handler(current_range, stream, std::nullopt) == continuation::abort) {
            break;
        }

        frame += sync_src.slice_length;
    }
}

proc::continuation timeline::_process_tracks(time::range const &current_range, stream &stream,
                                             process_track_f const &handler) {
    for (auto &track_pair : this->_tracks_holder->elements()) {
        track_pair.second->process(current_range, stream);

        if (handler(current_range, stream, track_pair.first) == continuation::abort) {
            return continuation::abort;
        }
    }
    return continuation::keep;
}

void timeline::_push_timeline_event(timeline_event const &event) {
    this->_fetcher->push(event);
}

void timeline::_observe_track(track_index_t const &track_idx) {
    auto canceller = this->_tracks_holder->at(track_idx)
                         ->observe([this, track_idx](track_event const &trk_event) {
                             this->_push_timeline_event({.type = timeline_event_type::relayed,
                                                         .tracks = this->_tracks_holder->elements(),
                                                         .relayed = &this->_tracks_holder->at(track_idx),
                                                         .index = track_idx,
                                                         .track_event = &trk_event});
                         })
                         .end();

    this->_track_cancellers.emplace(track_idx, std::move(canceller));
}

void timeline::_observe_all_tracks() {
    for (auto const &pair : this->_tracks_holder->elements()) {
        this->_observe_track(pair.first);
    }
}
