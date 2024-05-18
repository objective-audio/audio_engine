//
//  module_set.cpp
//

#include "module_set.h"

#include <audio-processing/module/module.h>
#include <audio-processing/module_set/module_set_utils.h>

using namespace yas;
using namespace yas::proc;

module_set::module_set(module_vector_t &&modules)
    : _modules_holder(module_vector_holder_t::make_shared(std::move(modules))) {
}

module_vector_t const &module_set::modules() const {
    return this->_modules_holder->value();
}

std::size_t module_set::size() const {
    return this->_modules_holder->size();
}

module_ptr const &module_set::at(std::size_t const idx) {
    return this->_modules_holder->at(idx);
}

void module_set::push_back(module_ptr const &module) {
    this->_modules_holder->push_back(module);
}

void module_set::insert(module_ptr const &module, std::size_t const idx) {
    this->_modules_holder->insert(module, idx);
}

bool module_set::erase(std::size_t const idx) {
    if (idx < this->_modules_holder->size()) {
        this->_modules_holder->erase(idx);
        return true;
    } else {
        return false;
    }
}

module_set_ptr module_set::copy() const {
    module_vector_t copied;
    copied.reserve(this->size());
    for (auto const &module : this->_modules_holder->value()) {
        copied.emplace_back(module->copy());
    }
    return module_set::make_shared(std::move(copied));
}

observing::syncable module_set::observe(observing_handler_f &&handler) {
    return this->_modules_holder->observe([this, handler = std::move(handler)](auto const &event) {
        handler({.type = to_module_set_event_type(event.type),
                 .modules = event.elements,
                 .inserted = event.inserted,
                 .erased = event.erased,
                 .index = event.index});
    });
}

module_set_ptr module_set::make_shared() {
    return make_shared({});
}

module_set_ptr module_set::make_shared(module_vector_t &&modules) {
    return module_set_ptr(new module_set{std::move(modules)});
}
