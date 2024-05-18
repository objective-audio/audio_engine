//
//  track.h
//

#pragma once

#include <audio-processing/track/track_types.h>

#include <optional>

namespace yas::proc {
class stream;

struct track final {
    [[nodiscard]] track_module_set_map_t const &module_sets() const;

    [[nodiscard]] std::optional<time::range> total_range() const;

    void push_back_module(module_ptr const &, time::range const &);
    void insert_module(module_ptr const &, module_index_t const, time::range const &);
    bool erase_module(module_ptr const &);
    bool erase_module(module_ptr const &, time::range const &);
    bool erase_module_at(module_index_t const, time::range const &);
    void erase_modules_for_range(time::range const &);

    [[nodiscard]] track_ptr copy() const;

    void process(time::range const &, stream &);

    using observing_handler_f = std::function<void(track_event const &)>;
    [[nodiscard]] observing::syncable observe(observing_handler_f &&);

    [[nodiscard]] static track_ptr make_shared();
    [[nodiscard]] static track_ptr make_shared(track_module_set_map_t &&);

   private:
    using track_module_set_map_holder_t = observing::map::holder<time::range, module_set_ptr>;
    using track_module_set_map_holder_ptr_t = observing::map::holder_ptr<time::range, module_set_ptr>;

    track_module_set_map_holder_ptr_t const _module_sets_holder;
    observing::fetcher_ptr<track_event> _fetcher = nullptr;
    observing::cancellable_ptr _module_sets_canceller = nullptr;
    std::map<time::range, observing::cancellable_ptr> _module_set_cancellers;

    explicit track(track_module_set_map_t &&);

    void _push_track_event(track_event const &);
    void _observe_module_set(time::range const &);
};
}  // namespace yas::proc
