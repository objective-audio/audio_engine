//
//  timeline_canceller.h
//

#pragma once

#include <audio-playing/common/ptr.h>

#include <audio-processing/umbrella.hpp>

namespace yas::playing {
struct timeline_canceller final {
    std::optional<proc::time::range> const range;

    // requestの範囲に完全に含まれていたらキャンセルさせる
    bool is_cancel(proc::time::range const &range) const;

    static timeline_cancel_matcher_ptr make_shared(std::optional<proc::time::range> const &);

   private:
    timeline_canceller(std::optional<proc::time::range> const &);
};
}  // namespace yas::playing
