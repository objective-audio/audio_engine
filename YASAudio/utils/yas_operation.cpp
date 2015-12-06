//
//  yas_operation.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_operation.h"
#include <thread>
#include <atomic>
#include <mutex>
#include <vector>
#include <deque>

using namespace yas;

#pragma mark - operation

class operation::impl : public base::impl {
   public:
    std::atomic<bool> canceled;
    execution_f execution;

    impl(const execution_f &exe) : canceled(false), execution(exe) {
    }
};

operation::operation(const execution_f &exe) : super_class(std::make_unique<impl>(exe)) {
}

operation::operation(std::nullptr_t) : super_class(nullptr) {
}

void operation::cancel() {
    _cancel();
}

bool operation::is_canceled() const {
    return impl_ptr<impl>()->canceled;
}

void operation::_execute() {
    if (auto &exe = impl_ptr<impl>()->execution) {
        if (!is_canceled()) {
            exe(*this);
        }
    }
}

void operation::_cancel() {
    impl_ptr<impl>()->canceled = true;
}

#pragma mark - queue

class operation_queue::impl : public base::impl {
   public:
    weak<operation_queue> weak_queue;

    impl(const size_t count) : _operations(count) {
    }

    ~impl() {
        cancel_all_operations();
    }

    void add_operation(const operation &op, const priority_t priority) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        auto &dq = _operations.at(priority);
        dq.push_back(op);

        _start_next_operation_if_needed();
    }

    void insert_operation_to_top(const operation &op, const priority_t priority) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        auto &dq = _operations.at(priority);
        dq.push_front(op);

        _start_next_operation_if_needed();
    }

    void cancel_operation(const operation &operation) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        for (auto &dq : _operations) {
            for (auto &op : dq) {
                if (operation == op) {
                    op.cancel();
                }
            }
        }

        if (_current_operation) {
            if (_current_operation == operation) {
                _current_operation.cancel();
            }
        }
    }

    void cancel_all_operations() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        for (auto &dq : _operations) {
            for (auto &op : dq) {
                op.cancel();
            }
            dq.clear();
        }

        if (_current_operation) {
            _current_operation.cancel();
        }
    }

    void suspend() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        _suspended = true;
    }

    void resume() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        if (_suspended) {
            _suspended = false;
            _start_next_operation_if_needed();
        }
    }

   private:
    operation _current_operation = nullptr;
    std::vector<std::deque<operation>> _operations;
    bool _suspended = false;
    mutable std::recursive_mutex _mutex;

    void _start_next_operation_if_needed() {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        if (!_current_operation && !_suspended) {
            operation op{nullptr};

            for (auto &dq : _operations) {
                if (!dq.empty()) {
                    op = dq.front();
                    dq.pop_front();
                    break;
                }
            }

            if (op) {
                _current_operation = op;

                std::thread th([weak_ope = to_weak(op), weak_queue = weak_queue]() {
                    if (auto ope = weak_ope.lock()) {
                        auto &ope_for_queue = static_cast<operation_from_queue &>(ope);
                        ope_for_queue._execute();

                        if (auto queue = weak_queue.lock()) {
                            queue.impl_ptr<impl>()->_operation_did_finish(ope);
                        }
                    }
                });

                th.detach();
            }
        }
    }

    void _operation_did_finish(const operation &prev_op) {
        std::lock_guard<std::recursive_mutex> lock(_mutex);

        if (_current_operation == prev_op) {
            _current_operation = nullptr;
        }

        _start_next_operation_if_needed();
    }
};

operation_queue::operation_queue(const size_t count) : super_class(std::make_unique<impl>(count)) {
    impl_ptr<impl>()->weak_queue = *this;
}

operation_queue::operation_queue(std::nullptr_t) : super_class(nullptr) {
}

void operation_queue::add_operation(const operation &op, const priority_t pr) {
    impl_ptr<impl>()->add_operation(op, pr);
}

void operation_queue::insert_operation_to_top(const operation &op, const priority_t pr) {
    impl_ptr<impl>()->insert_operation_to_top(op, pr);
}

void operation_queue::cancel_operation(const operation &op) {
    impl_ptr<impl>()->cancel_operation(op);
}

void operation_queue::cancel_all_operations() {
    impl_ptr<impl>()->cancel_all_operations();
}

void operation_queue::suspend() {
    impl_ptr<impl>()->suspend();
}

void operation_queue::resume() {
    impl_ptr<impl>()->resume();
}
