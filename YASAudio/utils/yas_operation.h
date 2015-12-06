//
//  yas_operation.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_base.h"
#include <MacTypes.h>
#include <memory>
#include <functional>

namespace yas {
class operation;

class operation_from_queue {
   public:
    virtual void _execute() = 0;
    virtual void _cancel() = 0;
};

class operation : public base, public operation_from_queue {
    using super_class = base;

   public:
    using execution_f = std::function<void(const operation &)>;

    explicit operation(const execution_f &);
    operation(std::nullptr_t);

    void cancel();
    bool is_canceled() const;

   private:
    class impl;

    void _execute() override;
    void _cancel() override;
};

class operation_queue : public base {
    using super_class = base;

   public:
    using priority_t = UInt32;

    explicit operation_queue(const size_t priority_count = 1);
    operation_queue(std::nullptr_t);

    void add_operation(const operation &, const priority_t pr = 0);
    void insert_operation_to_top(const operation &, const priority_t pr = 0);
    void cancel_operation(const operation &);
    void cancel_all_operations();

    void suspend();
    void resume();

   private:
    class impl;
};
}