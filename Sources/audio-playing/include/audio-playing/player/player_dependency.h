//
//  player_dependency.h
//

#pragma once

#include <audio-playing/common/ptr.h>
#include <audio-playing/renderer/renderer_types.h>

namespace yas::playing {
struct renderer_for_player {
    virtual ~renderer_for_player() = default;

    virtual void set_rendering_handler(renderer_rendering_f &&) = 0;
};

struct player_resource_for_player {
    using overwrite_requests_t = std::vector<element_address>;
    using overwrite_requests_f = std::function<void(overwrite_requests_t const &)>;

    virtual ~player_resource_for_player() = default;

    virtual std::shared_ptr<reading_resource_for_player_resource> const &reading() const = 0;
    virtual std::shared_ptr<buffering_resource_for_player_resource> const &buffering() const = 0;

    virtual void set_playing_on_main(bool const) = 0;
    [[nodiscard]] virtual bool is_playing_on_render() const = 0;

    virtual void seek_on_main(frame_index_t const frame) = 0;
    [[nodiscard]] virtual std::optional<frame_index_t> pull_seek_frame_on_render() = 0;
    [[nodiscard]] virtual bool is_seeking_on_main() const = 0;

    virtual void set_current_frame_on_render(frame_index_t const) = 0;
    [[nodiscard]] virtual frame_index_t current_frame() const = 0;

    virtual void add_overwrite_request_on_main(element_address &&) = 0;
    virtual void perform_overwrite_requests_on_render(overwrite_requests_f const &) = 0;
    virtual void reset_overwrite_requests_on_render() = 0;
};
}  // namespace yas::playing
