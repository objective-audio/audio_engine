//
//  player_resource.h
//

#pragma once

#include <audio-playing/common/ptr.h>
#include <audio-playing/player/player_dependency.h>
#include <audio-playing/player/player_resource_dependency.h>

#include <mutex>

namespace yas::playing {
struct player_resource final : player_resource_for_player {
    std::shared_ptr<reading_resource_for_player_resource> const &reading() const override;
    std::shared_ptr<buffering_resource_for_player_resource> const &buffering() const override;

    void set_playing_on_main(bool const) override;
    [[nodiscard]] bool is_playing_on_render() const override;

    void seek_on_main(frame_index_t const frame) override;
    [[nodiscard]] std::optional<frame_index_t> pull_seek_frame_on_render() override;
    [[nodiscard]] bool is_seeking_on_main() const override;

    void set_current_frame_on_render(frame_index_t const) override;
    [[nodiscard]] frame_index_t current_frame() const override;

    void add_overwrite_request_on_main(element_address &&) override;
    void perform_overwrite_requests_on_render(overwrite_requests_f const &) override;
    void reset_overwrite_requests_on_render() override;

    static player_resource_ptr make_shared(std::shared_ptr<reading_resource_for_player_resource> const &,
                                           std::shared_ptr<buffering_resource_for_player_resource> const &);

   private:
    std::shared_ptr<reading_resource_for_player_resource> const _reading;
    std::shared_ptr<buffering_resource_for_player_resource> const _buffering;

    std::atomic<bool> _is_playing{false};
    std::atomic<frame_index_t> _current_frame{0};

    std::mutex _seek_mutex;
    std::optional<frame_index_t> _seek_frame = std::nullopt;

    enum class seek_state {
        waiting,
        requested,
        pulled,
    };

    std::atomic<seek_state> _seek_state = seek_state::waiting;

    std::mutex _overwrite_mutex;
    overwrite_requests_t _overwrite_requests;
    bool _is_overwritten = false;

    player_resource(std::shared_ptr<reading_resource_for_player_resource> const &,
                    std::shared_ptr<buffering_resource_for_player_resource> const &);
};
}  // namespace yas::playing
