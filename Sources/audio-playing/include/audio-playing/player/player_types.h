//
//  player_types.h
//

#pragma once

#include <cstdint>

namespace yas::playing {
struct player_task_priority final {
    uint32_t setup = 0;
    uint32_t rendering = 1;
};
}  // namespace yas::playing
