//
//  exporter.h
//

#pragma once

#include <audio-playing/coordinator/coordinator_dependency.h>
#include <audio-playing/exporter/exporter_resource.h>
#include <audio-playing/timeline/timeline_container.h>

#include <ostream>

namespace yas::playing {
struct exporter final : exporter_for_coordinator {
    using method_t = exporter_method;
    using error_t = exporter_error;
    using result_t = exporter_result_t;
    using event_t = exporter_event;
    using task_priority_t = exporter_task_priority;
    using task_queue_t = exporter_task_queue;

    void set_timeline_container(timeline_container_ptr const &) override;

    [[nodiscard]] observing::endable observe_event(event_observing_handler_f &&) override;

    [[nodiscard]] static exporter_ptr make_shared(std::string const &root_path, std::shared_ptr<task_queue_t> const &,
                                                  task_priority_t const &);

   private:
    std::shared_ptr<task_queue_t> const _queue;
    task_priority_t const _priority;
    observing::value::holder_ptr<timeline_container_ptr> const _container;
    exporter_resource_ptr const _resource;

    observing::canceller_pool _pool;

    exporter(std::string const &root_path, std::shared_ptr<task_queue_t> const &, task_priority_t const &);

    void _receive_timeline_event(proc::timeline_event const &event);
    void _receive_relayed_timeline_event(proc::timeline_event const &event);
    void _receive_relayed_track_event(proc::track_event const &event, track_index_t const trk_idx);
    void _update_timeline(proc::timeline_track_map_t &&tracks);
    void _insert_track(proc::timeline_event const &event);
    void _erase_track(proc::timeline_event const &event);
    void _insert_module_set(track_index_t const trk_idx, proc::track_event const &event);
    void _erase_module_set(track_index_t const trk_idx, proc::track_event const &event);
    void _insert_module(track_index_t const trk_idx, proc::time::range const range,
                        proc::module_set_event const &event);
    void _erase_module(track_index_t const trk_idx, proc::time::range const range, proc::module_set_event const &event);
    void _push_export_task(proc::time::range const &range);
};
}  // namespace yas::playing

namespace yas {
std::string to_string(playing::exporter::method_t const &);
std::string to_string(playing::exporter::error_t const &);
};  // namespace yas

std::ostream &operator<<(std::ostream &, yas::playing::exporter::method_t const &);
std::ostream &operator<<(std::ostream &, yas::playing::exporter::error_t const &);
