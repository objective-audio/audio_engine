//
//  math.h
//

#pragma once

#include <cstdint>

namespace yas::playing::math {
int64_t mod_int(int64_t const value, uint64_t const interval);
int64_t floor_int(int64_t const value, uint64_t const interval);
int64_t ceil_int(int64_t const value, uint64_t const interval);
}  // namespace yas::playing::math
