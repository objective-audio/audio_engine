//
//  buffering_resource.h
//

#pragma once

#include <audio-playing/common/path.h>
#include <audio-playing/player/buffering_resource_dependency.h>
#include <audio-playing/player/buffering_resource_types.h>
#include <audio-playing/player/player_resource_dependency.h>

namespace yas::playing {
struct buffering_resource final : buffering_resource_for_player_resource {
    [[nodiscard]] setup_state_t setup_state() const override;
    [[nodiscard]] rendering_state_t rendering_state() const override;
    [[nodiscard]] std::size_t element_count() const override;
    [[nodiscard]] std::size_t channel_count_on_render() const override;
    [[nodiscard]] sample_rate_t fragment_length_on_render() const override;

    void set_creating_on_render(sample_rate_t const sample_rate, audio::pcm_format const &,
                                uint32_t const ch_count) override;
    [[nodiscard]] bool needs_create_on_render(sample_rate_t const sample_rate, audio::pcm_format const &,
                                              uint32_t const ch_count) override;
    void create_buffer_on_task() override;

    void set_all_writing_on_render(frame_index_t const) override;
    void write_all_elements_on_task() override;
    void advance_on_render(fragment_index_t const) override;
    [[nodiscard]] bool write_elements_if_needed_on_task() override;
    void overwrite_element_on_render(element_address const &) override;

    bool needs_all_writing_on_render() const override;
    void set_channel_mapping_request_on_main(channel_mapping const &) override;
    void set_identifier_request_on_main(std::string const &) override;

    [[nodiscard]] bool read_into_buffer_on_render(audio::pcm_buffer *, channel_index_t const,
                                                  frame_index_t const) override;

    using make_channel_f = std::function<std::shared_ptr<buffering_channel_for_buffering_resource>(
        std::size_t const, audio::format const &, sample_rate_t const)>;

    static buffering_resource_ptr make_shared(std::size_t const element_count, std::string const &root_path,
                                              make_channel_f &&);

    frame_index_t all_writing_frame_for_test() const;
    channel_mapping const &ch_mapping_for_test() const;
    std::string const &identifier_for_test() const;

   private:
    std::size_t const _element_count;
    std::string const _root_path;
    make_channel_f const _make_channel_handler;

    std::atomic<setup_state_t> _setup_state{setup_state_t::initial};
    sample_rate_t _sample_rate = 0;
    sample_rate_t _frag_length = 0;
    audio::pcm_format _pcm_format;
    std::optional<audio::format> _format = std::nullopt;
    std::size_t _ch_count = 0;
    std::optional<path::timeline> _tl_path = std::nullopt;

    std::atomic<rendering_state_t> _rendering_state{rendering_state_t::waiting};
    frame_index_t _all_writing_frame = 0;
    channel_mapping _ch_mapping;
    std::string _identifier = "";

    std::vector<std::shared_ptr<buffering_channel_for_buffering_resource>> _channels;

    mutable std::mutex _request_mutex;
    std::optional<channel_mapping> _ch_mapping_request = std::nullopt;
    std::optional<std::string> _identifier_request = std::nullopt;

    buffering_resource(std::size_t const element_count, std::string const &root_path, make_channel_f &&);

    std::optional<channel_mapping> _pull_ch_mapping_request_on_task();
    std::optional<std::string> _pull_identifier_request_on_task();
};
}  // namespace yas::playing
