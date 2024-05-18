//
//  playing_path.h
//

#pragma once

#include <audio-playing/common/types.h>
#include <audio-processing/time/time.h>
#include <cpp-utils/file_path.h>

#include <filesystem>

namespace yas::playing::path {
struct [[nodiscard]] timeline final {
    std::filesystem::path root_path;
    std::string identifier;
    sample_rate_t sample_rate;

    [[nodiscard]] std::filesystem::path value() const;

    bool operator==(timeline const &rhs) const;
    bool operator!=(timeline const &rhs) const;
};

struct [[nodiscard]] channel final {
    timeline timeline_path;
    channel_index_t channel_index;

    [[nodiscard]] std::filesystem::path value() const;

    bool operator==(channel const &rhs) const;
    bool operator!=(channel const &rhs) const;
};

struct [[nodiscard]] fragment final {
    channel channel_path;
    fragment_index_t fragment_index;

    [[nodiscard]] std::filesystem::path value() const;

    bool operator==(fragment const &rhs) const;
    bool operator!=(fragment const &rhs) const;
};

struct [[nodiscard]] signal_event final {
    fragment fragment_path;
    proc::time::range range;
    std::type_info const &sample_type;

    [[nodiscard]] std::filesystem::path value() const;

    bool operator==(signal_event const &rhs) const;
    bool operator!=(signal_event const &rhs) const;
};

struct [[nodiscard]] number_events final {
    fragment fragment_path;

    [[nodiscard]] std::filesystem::path value() const;

    bool operator==(number_events const &rhs) const;
    bool operator!=(number_events const &rhs) const;
};

[[nodiscard]] std::string timeline_name(std::string const &identifier, sample_rate_t const);
[[nodiscard]] std::string channel_name(channel_index_t const ch_idx);
[[nodiscard]] std::string fragment_name(fragment_index_t const frag_idx);
}  // namespace yas::playing::path
