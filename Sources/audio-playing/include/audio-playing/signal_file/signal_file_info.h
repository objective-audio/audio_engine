//
//  signal_file_info.h
//

#pragma once

#include <audio-processing/time/time.h>

#include <filesystem>
#include <optional>
#include <string>

namespace yas::playing {
struct signal_file_info {
    std::string const path;
    proc::time::range const range;
    std::type_info const &sample_type;

    signal_file_info(std::string const &path, proc::time::range const &, std::type_info const &);

    std::string file_name() const;
};

[[nodiscard]] std::string to_signal_file_name(proc::time::range const &, std::type_info const &);
[[nodiscard]] std::string to_sample_type_name(std::type_info const &);
[[nodiscard]] std::type_info const &to_sample_type(std::string const &);
[[nodiscard]] std::optional<signal_file_info> to_signal_file_info(std::filesystem::path const &path);
}  // namespace yas::playing
