//
//  exporter_resource.cpp
//

#include "exporter_resource.h"

#include <audio-playing/common/path.h>
#include <audio-playing/numbers_file/numbers_file.h>
#include <audio-playing/signal_file/signal_file.h>
#include <audio-playing/timeline/timeline_utils.h>
#include <cpp-utils/file_manager.h>
#include <cpp-utils/thread.h>
#include <cpp-utils/to_integer.h>
#include <dispatch/dispatch.h>

#include <audio-processing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

exporter_resource::exporter_resource(std::string const &root_path) : _root_path(root_path) {
}

void exporter_resource::replace_timeline_on_task(proc::timeline::track_map_t &&tracks, std::string const &identifier,
                                                 sample_rate_t const &sample_rate, task_t const &task) {
    this->_identifier = identifier;
    this->_timeline = proc::timeline::make_shared(std::move(tracks));
    this->_sync_source.emplace(sample_rate, sample_rate);

    if (task.is_canceled()) {
        return;
    }

    if (auto const result = file_manager::remove_content(this->_root_path); !result) {
        std::runtime_error("remove timeline root directory failed.");
    }

    this->_send_method_on_task(exporter_method::reset, std::nullopt);

    if (task.is_canceled()) {
        return;
    }

    proc::timeline_ptr const &timeline = this->_timeline;

    auto total_range = timeline->total_range();
    if (!total_range.has_value()) {
        return;
    }

    auto const &sync_source = this->_sync_source.value();
    auto const frags_range = timeline_utils::fragments_range(*total_range, sync_source.sample_rate);

    this->_send_method_on_task(exporter_method::export_began, frags_range);

    this->_export_fragments_on_task(frags_range, task);
}

void exporter_resource::insert_track_on_task(track_index_t const trk_idx, proc::track_ptr &&track) {
    this->_timeline->insert_track(trk_idx, std::move(track));
}

void exporter_resource::erase_track_on_task(track_index_t const trk_idx) {
    this->_timeline->erase_track(trk_idx);
}

void exporter_resource::insert_module_set_on_task(track_index_t const trk_idx, proc::time::range const &range,
                                                  proc::module_set_ptr &&module_set) {
    auto const &track = this->_timeline->track(trk_idx);
    assert(track->module_sets().count(range) == 0);

    for (auto const &module : module_set->modules()) {
        track->push_back_module(module, range);
    }
}

void exporter_resource::erase_module_set_on_task(track_index_t const trk_idx, proc::time::range const &range) {
    auto const &track = this->_timeline->track(trk_idx);
    assert(track->module_sets().count(range) > 0);
    track->erase_modules_for_range(range);
}

void exporter_resource::insert_module(proc::module_ptr const &module, module_index_t const module_idx,
                                      track_index_t const trk_idx, proc::time::range const range) {
    auto const &track = this->_timeline->track(trk_idx);
    assert(track->module_sets().count(range) > 0);
    track->insert_module(std::move(module), module_idx, range);
}

void exporter_resource::erase_module(module_index_t const module_idx, track_index_t const trk_idx,
                                     proc::time::range const range) {
    auto const &track = this->_timeline->track(trk_idx);
    assert(track->module_sets().count(range) > 0);
    track->erase_module_at(module_idx, range);
}

void exporter_resource::export_on_task(proc::time::range const &range, task_t const &task) {
    auto const &sync_source = this->_sync_source.value();
    auto frags_range = timeline_utils::fragments_range(range, sync_source.sample_rate);

    this->_send_method_on_task(exporter_method::export_began, frags_range);

    if (auto const error = this->_remove_fragments_on_task(frags_range, task)) {
        this->_send_error_on_task(*error, range);
    } else {
        this->_export_fragments_on_task(frags_range, task);
    }
}

void exporter_resource::_export_fragments_on_task(proc::time::range const &frags_range, task_t const &task) {
    assert(!thread::is_main());

    if (task.is_canceled()) {
        return;
    }

    this->_timeline->process(frags_range, this->_sync_source.value(),
                             [&task, this](proc::time::range const &range, proc::stream const &stream) {
                                 if (task.is_canceled()) {
                                     return proc::continuation::abort;
                                 }

                                 if (auto error = this->_export_fragment_on_task(range, stream)) {
                                     this->_send_error_on_task(*error, range);
                                 } else {
                                     this->_send_method_on_task(exporter_method::export_ended, range);
                                 }

                                 return proc::continuation::keep;
                             });
}

[[nodiscard]] std::optional<exporter_error> exporter_resource::_export_fragment_on_task(
    proc::time::range const &frag_range, proc::stream const &stream) {
    assert(!thread::is_main());

    auto const &sync_source = this->_sync_source.value();
    path::timeline const tl_path{this->_root_path, this->_identifier, sync_source.sample_rate};

    auto const frag_idx = frag_range.frame / stream.sync_source().sample_rate;

    for (auto const &ch_pair : stream.channels()) {
        auto const &ch_idx = ch_pair.first;
        auto const &channel = ch_pair.second;

        path::channel const ch_path{tl_path, ch_idx};
        auto const frag_path = path::fragment{ch_path, frag_idx};
        auto const frag_path_value = frag_path.value();

        auto remove_result = file_manager::remove_content(frag_path_value);
        if (!remove_result) {
            return exporter_error::remove_fragment_failed;
        }

        if (channel.events().size() == 0) {
            return std::nullopt;
        }

        auto const create_result = file_manager::create_directory_if_not_exists(frag_path_value);
        if (!create_result) {
            return exporter_error::create_directory_failed;
        }

        for (auto const &event_pair : channel.filtered_events<proc::signal_event>()) {
            proc::time::range const &range = event_pair.first;
            proc::signal_event_ptr const &event = event_pair.second;

            auto const signal_path_value = path::signal_event{frag_path, range, event->sample_type()}.value();

            if (auto const result = signal_file::write(signal_path_value, *event); !result) {
                return exporter_error::write_signal_failed;
            }
        }

        if (auto const number_events = channel.filtered_events<proc::number_event>(); number_events.size() > 0) {
            auto const number_path_value = path::number_events{frag_path}.value();

            if (auto const result = numbers_file::write(number_path_value, number_events); !result) {
                return exporter_error::write_numbers_failed;
            }
        }
    }

    return std::nullopt;
}

std::optional<exporter_error> exporter_resource::_remove_fragments_on_task(proc::time::range const &frags_range,
                                                                           task_t const &task) {
    assert(!thread::is_main());

    auto const &sync_source = this->_sync_source.value();
    auto const &sample_rate = sync_source.sample_rate;
    path::timeline const tl_path{this->_root_path, this->_identifier, sample_rate};

    auto ch_paths_result = file_manager::content_paths_in_directory(tl_path.value());
    if (!ch_paths_result) {
        if (ch_paths_result.error() == file_manager::content_paths_error::directory_not_found) {
            return std::nullopt;
        } else {
            return exporter_error::get_content_paths_failed;
        }
    }

    auto const ch_names = to_vector<std::string>(ch_paths_result.value(),
                                                 [](std::filesystem::path const &path) { return path.filename(); });

    auto const begin_frag_idx = frags_range.frame / sample_rate;
    auto const end_frag_idx = frags_range.next_frame() / sample_rate;

    for (auto const &ch_name : ch_names) {
        if (task.is_canceled()) {
            return std::nullopt;
        }

        auto const ch_idx = yas::to_integer<channel_index_t>(ch_name);
        path::channel const ch_path{tl_path, ch_idx};

        auto each = make_fast_each(begin_frag_idx, end_frag_idx);
        while (yas_each_next(each)) {
            auto const &frag_idx = yas_each_index(each);
            auto const frag_path_value = path::fragment{ch_path, frag_idx}.value();
            auto const remove_result = file_manager::remove_content(frag_path_value);
            if (!remove_result) {
                return exporter_error::remove_fragment_failed;
            }
        }
    }

    return std::nullopt;
}

void exporter_resource::_send_method_on_task(exporter_method const type,
                                             std::optional<proc::time::range> const &range) {
    assert(!thread::is_main());

    this->_send_event_on_task(exporter_event{.result = exporter_result_t{type}, .range = range});
}

void exporter_resource::_send_error_on_task(exporter_error const type, std::optional<proc::time::range> const &range) {
    assert(!thread::is_main());

    this->_send_event_on_task(exporter_event{.result = exporter_result_t{type}, .range = range});
}

void exporter_resource::_send_event_on_task(exporter_event event) {
    auto lambda = [event = std::move(event), weak_notifier = to_weak(this->event_notifier)] {
        if (auto notifier = weak_notifier.lock()) {
            notifier->notify(event);
        }
    };

    thread::perform_async_on_main(std::move(lambda));
}

exporter_resource_ptr exporter_resource::make_shared(std::string const &root_path) {
    return exporter_resource_ptr{new exporter_resource{root_path}};
}
