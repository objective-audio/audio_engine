//
//  timeline.h
//

#pragma once

#include <audio-processing/time/time.h>
#include <audio-processing/timeline/timeline_types.h>
#include <audio-processing/track/track.h>

#include <functional>
#include <optional>

namespace yas::proc {
class sync_source;

struct timeline final {
    using process_track_f =
        std::function<continuation(time::range const &, stream const &, std::optional<track_index_t> const &)>;
    using process_f = std::function<continuation(time::range const &, stream const &)>;
    using track_map_t = timeline_track_map_t;

    [[nodiscard]] static timeline_ptr make_shared();
    [[nodiscard]] static timeline_ptr make_shared(track_map_t &&);

    [[nodiscard]] track_map_t const &tracks() const;

    void replace_tracks(track_map_t &&);
    bool insert_track(track_index_t const, track_ptr const &);
    void erase_track(track_index_t const);
    void erase_all_tracks();
    [[nodiscard]] std::size_t track_count() const;
    [[nodiscard]] bool has_track(track_index_t const) const;
    [[nodiscard]] track_ptr const &track(track_index_t const) const;

    [[nodiscard]] std::optional<time::range> total_range() const;

    [[nodiscard]] timeline_ptr copy() const;

    /// 1回だけ処理する
    void process(time::range const &, stream &);
    /// スライス分の処理を繰り返す
    void process(time::range const &, sync_source const &, process_f const &);
    void process(time::range const &, sync_source const &, process_track_f const &);

    using observing_handler_f = std::function<void(timeline_event const &)>;
    [[nodiscard]] observing::syncable observe(observing_handler_f &&);

   private:
    using tracks_holder_t = observing::map::holder<track_index_t, track_ptr>;
    using tracks_holder_ptr_t = observing::map::holder_ptr<track_index_t, track_ptr>;

    tracks_holder_ptr_t const _tracks_holder;
    observing::fetcher_ptr<timeline_event> _fetcher = nullptr;
    observing::cancellable_ptr _tracks_canceller = nullptr;
    std::map<track_index_t, observing::cancellable_ptr> _track_cancellers;

    timeline(track_map_t &&);

    void _process_continuously(time::range const &range, sync_source const &sync_src, process_track_f const &handler);
    continuation _process_tracks(time::range const &, stream &, process_track_f const &);
    void _push_timeline_event(timeline_event const &);
    void _observe_track(track_index_t const &);
    void _observe_all_tracks();
};
}  // namespace yas::proc
