//
//  yas_playing_sample_controller.hpp
//

#pragma once

#include <audio-engine/umbrella.hpp>
#include <audio-playing/umbrella.hpp>
#include <audio-processing/umbrella.hpp>
#include <cpp-utils/umbrella.hpp>
#include <observing/umbrella.hpp>

namespace yas::playing::sample {
struct controller {
    audio::io_device_ptr const device;
    renderer_ptr const renderer = renderer::make_shared(this->device);
    std::string const root_path =
        file_path{system_path_utils::directory_path(system_path_utils::dir::document)}.appending("sample").string();
    std::string const identifier = "0";
    coordinator_ptr const coordinator = coordinator::make_shared(this->root_path, renderer);

    observing::value::holder_ptr<float> const frequency = observing::value::holder<float>::make_shared(1000.0f);
    observing::value::holder_ptr<channel_index_t> const ch_mapping_idx =
        observing::value::holder<channel_index_t>::make_shared(0);

    void seek_zero();
    void seek_plus_one_sec();
    void seek_minus_one_sec();

    static std::shared_ptr<controller> make_shared(audio::io_device_ptr const &);

   private:
    proc::timeline_ptr _timeline = nullptr;
    observing::value::holder_ptr<sample_rate_t> const _sample_rate =
        observing::value::holder<sample_rate_t>::make_shared(0);

    observing::canceller_pool _pool;

    controller(audio::io_device_ptr const &);

    void _update_timeline();
    void _update_pi_track();
    proc::timeline_ptr make_timeline();
};
}  // namespace yas::playing::sample
