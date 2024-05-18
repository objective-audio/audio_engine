//
//  player.h
//

#pragma once

#include <audio-playing/common/channel_mapping.h>
#include <audio-playing/common/ptr.h>
#include <audio-playing/common/types.h>
#include <audio-playing/coordinator/coordinator_dependency.h>
#include <audio-playing/player/player_dependency.h>
#include <audio-playing/player/player_types.h>
#include <cpp-utils/worker.h>

namespace yas::playing {
struct player final : player_for_coordinator {
    void set_identifier(std::string const &) override;
    void set_channel_mapping(playing::channel_mapping const &) override;
    void set_playing(bool const) override;
    void seek(frame_index_t const) override;
    void overwrite(std::optional<channel_index_t> const file_ch_idx, fragment_range const) override;

    [[nodiscard]] std::string const &identifier() const override;
    [[nodiscard]] playing::channel_mapping channel_mapping() const override;
    [[nodiscard]] bool is_playing() const override;
    [[nodiscard]] bool is_seeking() const override;
    [[nodiscard]] frame_index_t current_frame() const override;

    [[nodiscard]] observing::syncable observe_is_playing(std::function<void(bool const &)> &&) override;

    static player_ptr make_shared(std::string const &root_path, std::shared_ptr<renderer_for_player> const &,
                                  workable_ptr const &, player_task_priority const &,
                                  std::shared_ptr<player_resource_for_player> const &);

   private:
    std::shared_ptr<renderer_for_player> const _renderer;
    workable_ptr const _worker;
    player_task_priority const _priority;
    std::shared_ptr<player_resource_for_player> const _resource;

    observing::value::holder_ptr<bool> _is_playing = observing::value::holder<bool>::make_shared(false);
    playing::channel_mapping _ch_mapping;
    std::string _identifier;
    observing::canceller_pool _pool;

    player(std::string const &root_path, std::shared_ptr<renderer_for_player> const &, workable_ptr const &,
           player_task_priority const &, std::shared_ptr<player_resource_for_player> const &);
};
}  // namespace yas::playing
