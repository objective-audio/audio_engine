//
//  module_set.h
//

#pragma once

#include <audio-processing/module_set/module_set_types.h>

namespace yas::proc {
struct module_set final {
    [[nodiscard]] module_vector_t const &modules() const;
    [[nodiscard]] std::size_t size() const;
    [[nodiscard]] module_ptr const &at(std::size_t const);

    void push_back(module_ptr const &);
    void insert(module_ptr const &, std::size_t const);
    bool erase(std::size_t const);

    [[nodiscard]] module_set_ptr copy() const;

    using observing_handler_f = std::function<void(module_set_event const &)>;
    [[nodiscard]] observing::syncable observe(observing_handler_f &&);

    [[nodiscard]] static module_set_ptr make_shared();
    [[nodiscard]] static module_set_ptr make_shared(module_vector_t &&);

   private:
    module_vector_holder_ptr_t _modules_holder;

    module_set(module_vector_t &&);
};
}  // namespace yas::proc
