//
//  number_event_private.h
//

#pragma once

#include <audio-processing/time/time.h>

namespace yas {
struct proc::number_event::impl {
    virtual std::type_info const &type() const = 0;
    virtual std::size_t sample_byte_count() const = 0;
    virtual number_event_ptr copy() = 0;
    virtual bool is_equal(std::shared_ptr<number_event::impl> const &) const = 0;
};
}  // namespace yas
