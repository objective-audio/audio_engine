//
//  track.cpp
//

#include "track.h"

#include <audio-processing/module/module.h>
#include <audio-processing/module_set/module_set.h>
#include <audio-processing/stream/stream.h>
#include <cpp-utils/stl_utils.h>

#include "track_utils.h"

using namespace yas;
using namespace yas::proc;

track::track(track_module_set_map_t &&modules)
    : _module_sets_holder(track_module_set_map_holder_t::make_shared(std::move(modules))) {
    this->_fetcher = observing::fetcher<track_event>::make_shared([this] {
        return track_event{.type = track_event_type::any, .module_sets = this->_module_sets_holder->elements()};
    });

    this->_module_sets_canceller = this->_module_sets_holder
                                       ->observe([this](track_module_set_map_holder_t::event const &module_sets_event) {
                                           this->_push_track_event({.type = to_track_event_type(module_sets_event.type),
                                                                    .module_sets = module_sets_event.elements,
                                                                    .inserted = module_sets_event.inserted,
                                                                    .erased = module_sets_event.erased,
                                                                    .range = module_sets_event.key});
                                       })
                                       .end();
}

track_module_set_map_t const &track::module_sets() const {
    return this->_module_sets_holder->elements();
}

std::optional<time::range> track::total_range() const {
    std::optional<time::range> result{std::nullopt};

    for (auto const &pair : this->_module_sets_holder->elements()) {
        if (result) {
            result = result->merged(pair.first);
        } else {
            result = pair.first;
        }
    }

    return result;
}

void track::push_back_module(module_ptr const &module, time::range const &range) {
    auto const idx = this->_module_sets_holder->contains(range) ? this->_module_sets_holder->at(range)->size() : 0;
    this->insert_module(module, idx, range);
}

void track::insert_module(module_ptr const &module, module_index_t const idx, time::range const &range) {
    if (this->_module_sets_holder->contains(range) && idx <= this->_module_sets_holder->at(range)->size()) {
        this->_module_sets_holder->at(range)->insert(module, idx);
    } else if (idx == 0) {
        this->_module_sets_holder->insert_or_replace(range, module_set::make_shared({module}));
        this->_observe_module_set(range);
    } else {
        throw std::out_of_range(std::string(__PRETTY_FUNCTION__) + " : out of range. index(" + std::to_string(idx) +
                                ")");
    }
}

bool track::erase_module(module_ptr const &erasing) {
    std::optional<time::range> range;

    for (auto const &pair : this->_module_sets_holder->elements()) {
        for (auto const &module : pair.second->modules()) {
            if (module == erasing) {
                range = pair.first;
                break;
            }
        }
    }

    return range.has_value() && this->erase_module(erasing, range.value());
}

bool track::erase_module(module_ptr const &erasing, time::range const &range) {
    if (this->_module_sets_holder->contains(range)) {
        auto const &module_set = this->_module_sets_holder->at(range);

        std::size_t idx = 0;
        for (auto const &module : module_set->modules()) {
            if (module == erasing) {
                if (module_set->size() == 1) {
                    this->_module_set_cancellers.erase(range);
                    this->_module_sets_holder->erase(range);
                } else {
                    module_set->erase(idx);
                }
                return true;
            }
            ++idx;
        }
    }
    return false;
}

bool track::erase_module_at(module_index_t const idx, time::range const &range) {
    if (this->_module_sets_holder->contains(range)) {
        auto const &module_set = this->_module_sets_holder->at(range);
        if (idx < module_set->size()) {
            if (idx == 0 && module_set->size() == 1) {
                this->_module_set_cancellers.erase(range);
                this->_module_sets_holder->erase(range);
            } else {
                module_set->erase(idx);
            }
            return true;
        }
    }
    return false;
}

void track::erase_modules_for_range(time::range const &range) {
    this->_module_sets_holder->erase(range);
}

track_ptr track::copy() const {
    return track::make_shared(proc::copy_module_sets(this->_module_sets_holder->elements()));
}

void track::process(time::range const &time_range, stream &stream) {
    for (auto const &pair : this->_module_sets_holder->elements()) {
        if (auto const current_time_range = pair.first.intersected(time_range)) {
            for (auto &module : pair.second->modules()) {
                module->process(*current_time_range, stream);
            }
        }
    }
}

observing::syncable track::observe(observing_handler_f &&handler) {
    return this->_fetcher->observe(std::move(handler));
}

void track::_push_track_event(track_event const &track_event) {
    this->_fetcher->push(track_event);
}

void track::_observe_module_set(time::range const &range) {
    auto canceller = this->_module_sets_holder->at(range)
                         ->observe([this, range](module_set_event const &set_event) {
                             this->_push_track_event({.type = track_event_type::relayed,
                                                      .module_sets = this->_module_sets_holder->elements(),
                                                      .relayed = &this->_module_sets_holder->at(range),
                                                      .range = range,
                                                      .module_set_event = &set_event});
                         })
                         .end();

    this->_module_set_cancellers.emplace(range, std::move(canceller));
}

track_ptr track::make_shared() {
    return make_shared({});
}

track_ptr track::make_shared(track_module_set_map_t &&modules) {
    return track_ptr(new track{std::move(modules)});
}
