//
//  exporter.cpp
//

#include "exporter.h"

#include <audio-engine/file/file.h>
#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/math.h>
#include <audio-playing/common/path.h>
#include <audio-playing/common/types.h>
#include <audio-playing/numbers_file/numbers_file.h>
#include <audio-playing/signal_file/signal_file.h>
#include <audio-playing/timeline/timeline_canceller.h>
#include <audio-playing/timeline/timeline_utils.h>
#include <audio-processing/timeline/timeline_utils.h>
#include <cpp-utils/fast_each.h>
#include <cpp-utils/file_manager.h>
#include <cpp-utils/task_queue.h>
#include <cpp-utils/thread.h>

#include <audio-processing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

exporter::exporter(std::string const &root_path, std::shared_ptr<task_queue_t> const &queue,
                   task_priority_t const &priority)
    : _queue(queue),
      _priority(priority),
      _container(
          observing::value::holder<timeline_container_ptr>::make_shared(timeline_container::make_shared_empty())),
      _resource(exporter_resource::make_shared(root_path)) {
    this->_container
        ->observe(
            [this, canceller = observing::cancellable_ptr{nullptr}](timeline_container_ptr const &container) mutable {
                if (canceller) {
                    canceller->cancel();
                    canceller = nullptr;
                }

                if (container->is_available()) {
                    container->timeline()
                        ->get()
                        ->observe([this](proc::timeline_event const &event) { this->_receive_timeline_event(event); })
                        .sync()
                        ->set_to(canceller);
                }
            })
        .end()
        ->add_to(this->_pool);
}

void exporter::set_timeline_container(timeline_container_ptr const &container) {
    assert(thread::is_main());

    this->_container->set_value(container);
}

observing::endable exporter::observe_event(event_observing_handler_f &&handler) {
    return this->_resource->event_notifier->observe(std::move(handler));
}

void exporter::_receive_timeline_event(proc::timeline_event const &event) {
    switch (event.type) {
        case proc::timeline_event_type::any: {
            this->_update_timeline(proc::copy_tracks(event.tracks));
        } break;
        case proc::timeline_event_type::inserted: {
            this->_insert_track(event);
        } break;
        case proc::timeline_event_type::erased: {
            this->_erase_track(event);
        } break;
        case proc::timeline_event_type::relayed: {
            this->_receive_relayed_timeline_event(event);
        } break;
        default:
            throw std::runtime_error("unreachable code.");
    }
}

void exporter::_receive_relayed_timeline_event(proc::timeline_event const &event) {
    switch (event.track_event->type) {
        case proc::track_event_type::inserted: {
            this->_insert_module_set(*event.index, *event.track_event);
        } break;
        case proc::track_event_type::erased: {
            this->_erase_module_set(*event.index, *event.track_event);
        } break;
        case proc::track_event_type::relayed: {
            this->_receive_relayed_track_event(*event.track_event, *event.index);
        } break;
        default:
            throw std::runtime_error("unreachable code.");
    }
}

void exporter::_receive_relayed_track_event(proc::track_event const &event, track_index_t const trk_idx) {
    switch (event.module_set_event->type) {
        case proc::module_set_event_type::inserted:
            this->_insert_module(trk_idx, *event.range, *event.module_set_event);
            break;
        case proc::module_set_event_type::erased:
            this->_erase_module(trk_idx, *event.range, *event.module_set_event);
            break;
        default:
            throw std::runtime_error("unreachable code.");
    }
}

void exporter::_update_timeline(proc::timeline::track_map_t &&tracks) {
    assert(thread::is_main());

    this->_queue->cancel_all();

    auto const &container = this->_container->value();

    auto task = exporter_task::make_shared(
        [resource = this->_resource, tracks = std::move(tracks), identifier = container->identifier(),
         sample_rate = container->sample_rate()](auto const &task) mutable {
            resource->replace_timeline_on_task(std::move(tracks), identifier, sample_rate, task);
        },
        {.priority = this->_priority.timeline});

    this->_queue->push_back(std::move(task));
}

void exporter::_insert_track(proc::timeline_event const &event) {
    assert(thread::is_main());

    auto copied_track = (*event.inserted)->copy();
    std::optional<proc::time::range> const total_range = copied_track->total_range();

    auto const insert_task = exporter_task::make_shared(
        [resource = this->_resource, trk_idx = *event.index, track = std::move(copied_track)](auto const &) mutable {
            resource->insert_track_on_task(trk_idx, std::move(track));
        },
        {.priority = this->_priority.timeline});
    this->_queue->push_back(insert_task);

    if (total_range) {
        this->_push_export_task(*total_range);
    }
}

void exporter::_erase_track(proc::timeline_event const &event) {
    assert(thread::is_main());

    std::optional<proc::time::range> const total_range = (*event.erased)->total_range();

    auto const erase_task = exporter_task::make_shared(
        [resource = this->_resource, trk_idx = *event.index](auto const &) { resource->erase_track_on_task(trk_idx); },
        {.priority = this->_priority.timeline});
    this->_queue->push_back(std::move(erase_task));

    if (total_range) {
        this->_push_export_task(*total_range);
    }
}

void exporter::_insert_module_set(track_index_t const trk_idx, proc::track_event const &event) {
    assert(thread::is_main());

    auto const copied_module_set = (*event.inserted)->copy();
    auto const &range = *event.range;

    auto task = exporter_task::make_shared(
        [resource = this->_resource, trk_idx, range, module_set = std::move(copied_module_set)](auto const &) mutable {
            resource->insert_module_set_on_task(trk_idx, range, std::move(module_set));
        },
        {.priority = this->_priority.timeline});
    this->_queue->push_back(std::move(task));

    this->_push_export_task(range);
}

void exporter::_erase_module_set(track_index_t const trk_idx, proc::track_event const &event) {
    assert(thread::is_main());

    auto const copied_module_set = (*event.erased)->copy();

    auto const &range = *event.range;
    auto task = exporter_task::make_shared([resource = this->_resource, trk_idx, range](
                                               auto const &) { resource->erase_module_set_on_task(trk_idx, range); },
                                           {.priority = this->_priority.timeline});
    this->_queue->push_back(std::move(task));

    this->_push_export_task(range);
}

void exporter::_insert_module(track_index_t const trk_idx, proc::time::range const range,
                              proc::module_set_event const &event) {
    assert(thread::is_main());

    auto task = exporter_task::make_shared(
        [resource = this->_resource, trk_idx, range, module_idx = *event.index, module = (*event.inserted)->copy()](
            auto const &) { resource->insert_module(module, module_idx, trk_idx, range); },
        {.priority = this->_priority.timeline});

    this->_queue->push_back(std::move(task));

    this->_push_export_task(range);
}

void exporter::_erase_module(track_index_t const trk_idx, proc::time::range const range,
                             proc::module_set_event const &event) {
    assert(thread::is_main());

    auto task = exporter_task::make_shared([resource = this->_resource, trk_idx, range, module_idx = *event.index](
                                               auto const &) { resource->erase_module(module_idx, trk_idx, range); },
                                           {.priority = this->_priority.timeline});

    this->_queue->push_back(std::move(task));

    this->_push_export_task(range);
}

void exporter::_push_export_task(proc::time::range const &range) {
    this->_queue->cancel([range](timeline_cancel_matcher_ptr const &matcher) { return matcher->is_cancel(range); });

    auto export_task = exporter_task::make_shared(
        [resource = this->_resource, range](auto const &task) { resource->export_on_task(range, task); },
        {.priority = this->_priority.fragment, .canceller = timeline_canceller::make_shared(range)});

    this->_queue->push_back(std::move(export_task));
}

exporter_ptr exporter::make_shared(std::string const &root_path, std::shared_ptr<task_queue_t> const &task_queue,
                                   task_priority_t const &task_priority) {
    return exporter_ptr(new exporter{root_path, task_queue, task_priority});
}

std::string yas::to_string(exporter::method_t const &method) {
    switch (method) {
        case exporter::method_t::reset:
            return "reset";
        case exporter::method_t::export_began:
            return "export_began";
        case exporter::method_t::export_ended:
            return "export_ended";
    }
}

std::string yas::to_string(exporter::error_t const &error) {
    switch (error) {
        case exporter::error_t::remove_fragment_failed:
            return "remove_fragment_failed";
        case exporter::error_t::create_directory_failed:
            return "create_directory_failed";
        case exporter::error_t::write_signal_failed:
            return "write_signal_failed";
        case exporter::error_t::write_numbers_failed:
            return "write_numbers_failed";
        case exporter::error_t::get_content_paths_failed:
            return "get_content_paths_failed";
    }
}

std::ostream &operator<<(std::ostream &stream, exporter::method_t const &value) {
    stream << to_string(value);
    return stream;
}

std::ostream &operator<<(std::ostream &stream, exporter::error_t const &value) {
    stream << to_string(value);
    return stream;
}
