//
//  test_utils.h
//

#pragma once

#include <audio-processing/umbrella.hpp>

namespace yas::playing::test_utils {
std::filesystem::path root_path();
std::string const identifier = "0";
proc::timeline_ptr test_timeline(int64_t const offset, uint32_t const ch_count);
}  // namespace yas::playing::test_utils
