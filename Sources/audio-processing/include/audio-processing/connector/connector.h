//
//  connector.h
//

#pragma once

#include <audio-processing/common/common_types.h>

#include <map>
#include <optional>
#include <string>

namespace yas::proc {
struct connector {
    channel_index_t channel_index;
};

using connector_map_t = std::map<connector_index_t, connector>;

template <typename T>
[[nodiscard]] connector_index_t to_connector_index(T const &);
}  // namespace yas::proc

#include "connector_private.h"
