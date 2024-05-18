//
//  timeline_canceller.cpp
//

#include "timeline_canceller.h"

using namespace yas;
using namespace yas::playing;

#pragma mark - cancel_matcher

timeline_canceller::timeline_canceller(std::optional<proc::time::range> const &range) : range(range) {
}

bool timeline_canceller::is_cancel(proc::time::range const &range) const {
    if (this->range.has_value()) {
        return range.is_contain(this->range.value());
    } else {
        return false;
    }
}

timeline_cancel_matcher_ptr timeline_canceller::make_shared(std::optional<proc::time::range> const &range) {
    return timeline_cancel_matcher_ptr(new timeline_canceller{range});
}
