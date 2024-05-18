//
//  module_set_types.h
//

#pragma once

#include <audio-processing/common/ptr.h>

#include <observing/umbrella.hpp>
#include <vector>

namespace yas::proc {
using module_vector_t = std::vector<module_ptr>;
using module_vector_holder_t = observing::vector::holder<module_ptr>;
using module_vector_holder_ptr_t = observing::vector::holder_ptr<module_ptr>;

enum class module_set_event_type {
    any,
    replaced,
    inserted,
    erased,
};

struct module_set_event {
    module_set_event_type type;
    std::vector<module_ptr> const &modules;
    module_ptr const *inserted = nullptr;
    module_ptr const *erased = nullptr;
    std::optional<std::size_t> index = std::nullopt;
};
}  // namespace yas::proc
