//
//  yas_playing_test_utils.cpp
//

#include "test_utils.h"
#include <audio-playing/umbrella.hpp>
#include <cpp-utils/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

std::filesystem::path test_utils::root_path() {
    auto path = system_path_utils::directory_path(system_path_utils::dir::temporary);
    return path.append("yas_playing_test_root");
}

proc::timeline_ptr test_utils::test_timeline(int64_t const offset, uint32_t const ch_count) {
    proc::timeline_ptr timeline = proc::timeline::make_shared();
    track_index_t trk_idx = 0;
    proc::time::range const module_range{-3, 18};

    if (auto track = proc::track::make_shared()) {
        if (auto module = proc::make_signal_module<int64_t>(proc::generator::kind::frame, offset)) {
            module->connect_output(proc::to_connector_index(proc::generator::output::value), -1);
            track->push_back_module(module, module_range);
        }
        timeline->insert_track(trk_idx++, track);
    }

    if (auto track = proc::track::make_shared()) {
        if (auto module = proc::cast::make_signal_module<int64_t, int16_t>()) {
            module->connect_input(proc::to_connector_index(proc::cast::input::value), -1);
            module->connect_output(proc::to_connector_index(proc::cast::output::value), -1);
            track->push_back_module(module, module_range);
        }
        timeline->insert_track(trk_idx++, track);
    }

    auto each = make_fast_each(ch_count);
    while (yas_each_next(each)) {
        auto const &ch_idx = yas_each_index(each);

        if (auto track = proc::track::make_shared()) {
            if (auto module = proc::make_signal_module<int16_t>(1000 * ch_idx)) {
                module->connect_output(proc::to_connector_index(proc::constant::output::value), ch_idx);
                track->push_back_module(module, module_range);
            }
            timeline->insert_track(trk_idx++, track);
        }

        if (auto track = proc::track::make_shared()) {
            if (auto module = proc::make_signal_module<int16_t>(proc::math2::kind::plus)) {
                module->connect_input(proc::to_connector_index(proc::math2::input::left), -1);
                module->connect_input(proc::to_connector_index(proc::math2::input::right), ch_idx);
                module->connect_output(proc::to_connector_index(proc::math2::output::result), ch_idx);
                track->push_back_module(module, module_range);
            }
            timeline->insert_track(trk_idx++, track);
        }
    }

    return timeline;
}
