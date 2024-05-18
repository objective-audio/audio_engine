//
//  time.cpp
//

#include "time.h"

#include <string>

using namespace yas;
using namespace yas::proc;

#pragma mark - time::range

proc::time::range::range(frame_index_t const frame, length_t const length) : frame(frame), length(length) {
    if (this->length == 0) {
        throw "length is zero.";
    }
}

bool proc::time::range::operator==(time::range const &rhs) const {
    return this->frame == rhs.frame && this->length == rhs.length;
}

bool proc::time::range::operator!=(time::range const &rhs) const {
    return this->frame != rhs.frame || this->length != rhs.length;
}

bool proc::time::range::operator<(time::range const &rhs) const {
    if (this->frame != rhs.frame) {
        return this->frame < rhs.frame;
    }

    return this->length < rhs.length;
}

proc::frame_index_t proc::time::range::next_frame() const {
    return this->frame + this->length;
}

bool proc::time::range::is_contain(time::range const &rhs) const {
    if (this->length == 0) {
        return false;
    }

    if (this->frame > rhs.frame) {
        return false;
    }

    if (rhs.length > 0) {
        return rhs.next_frame() <= next_frame();
    } else {
        return rhs.frame < next_frame();
    }
}

bool proc::time::range::is_contain(frame::type const &rhs_frame) const {
    return this->frame <= rhs_frame && rhs_frame < next_frame();
}

bool proc::time::range::is_contain(any::type const &any) const {
    return true;
}

bool proc::time::range::is_overlap(time::range const &rhs) const {
    if (this->length == 0 || rhs.length == 0) {
        return false;
    }

    return std::max(this->frame, rhs.frame) < std::min(next_frame(), rhs.next_frame());
}

bool proc::time::range::can_combine(time::range const &rhs) const {
    if (this->length == 0 || rhs.length == 0) {
        return false;
    }

    bool const is_this_lower = this->frame <= rhs.frame;
    auto const &lower_range = is_this_lower ? *this : rhs;
    auto const &higher_range = is_this_lower ? rhs : *this;
    return lower_range.next_frame() >= higher_range.frame;
}

std::optional<proc::time::range> proc::time::range::intersected(time::range const &rhs) const {
    auto const start = std::max(this->frame, rhs.frame);
    auto const next = std::min(next_frame(), rhs.next_frame());

    if (start < next) {
        return time::range{start, static_cast<length_t>(next - start)};
    } else {
        return std::nullopt;
    }
}

std::optional<proc::time::range> proc::time::range::combined(time::range const &other) const {
    if (!can_combine(other)) {
        return std::nullopt;
    }

    auto const start = std::min(this->frame, other.frame);
    auto const next = std::max(next_frame(), other.next_frame());

    return time::range{start, static_cast<length_t>(next - start)};
}

std::vector<proc::time::range> proc::time::range::cropped(range const &other) const {
    std::vector<proc::time::range> vec;

    if (!is_overlap(other)) {
        vec.push_back(*this);
        return vec;
    }

    if (auto const cropped_ragne_opt = intersected(other)) {
        auto const &cropped_range = *cropped_ragne_opt;
        if (this->frame < cropped_range.frame) {
            vec.emplace_back(time::range{this->frame, static_cast<length_t>(cropped_range.frame - this->frame)});
        }

        auto const cropped_next_frame = cropped_range.next_frame();
        auto const current_next_frame = next_frame();
        if (cropped_next_frame < current_next_frame) {
            vec.emplace_back(
                time::range{cropped_next_frame, static_cast<length_t>(current_next_frame - cropped_next_frame)});
        }
    }

    return vec;
}

proc::time::range proc::time::range::merged(range const &other) const {
    auto const start = std::min(this->frame, other.frame);
    auto const next = std::max(next_frame(), other.next_frame());

    return time::range{start, static_cast<length_t>(next - start)};
}

proc::time::range proc::time::range::offset(frame_index_t const &offset) const {
    return time::range{this->frame + offset, this->length};
}

#pragma mark - time::any

bool proc::time::any::operator==(time::any const &) const {
    return true;
}

bool proc::time::any::operator!=(time::any const &) const {
    return false;
}

#pragma mark - time::impl

struct proc::time::impl_base {
    virtual std::type_info const &type() const = 0;
    virtual bool is_equal(std::shared_ptr<impl_base> const &) const = 0;
};

template <typename T>
struct proc::time::impl : impl_base {
    typename T::type _value;

    impl(typename T::type const &val) : _value(val) {
    }

    impl(typename T::type &&val) : _value(std::move(val)) {
    }

    virtual bool is_equal(std::shared_ptr<impl_base> const &rhs) const override {
        if (auto casted_rhs = std::dynamic_pointer_cast<impl>(rhs)) {
            auto const &type_info = typeid(T);
            if (type_info == casted_rhs->type()) {
                return this->_value == casted_rhs->_value;
            }
        }

        return false;
    }

    std::type_info const &type() const override {
        return typeid(T);
    }
};

#pragma mark - proc::time

proc::time::time(frame_index_t const frame, length_t const length)
    : _impl(std::make_shared<impl<time::range>>(time::range{frame, length})) {
}

proc::time::time(range range) : _impl(std::make_shared<impl<time::range>>(std::move(range))) {
}

proc::time::time(frame_index_t const frame) : _impl(std::make_shared<impl<time::frame>>(frame)) {
}

proc::time::time() : _impl(any_impl_ptr()) {
}

proc::time::time(std::nullptr_t) : _impl(nullptr) {
}

proc::time &proc::time::operator=(time::range const &range) {
    this->_impl = std::make_shared<impl<time::range>>(range);
    return *this;
}

proc::time &proc::time::operator=(time::range &&range) {
    this->_impl = std::make_shared<impl<time::range>>(std::move(range));
    return *this;
}

bool proc::time::operator<(time const &rhs) const {
    if (this->is_any_type()) {
        if (rhs.is_any_type()) {
            return false;
        } else {
            return true;
        }
    } else if (rhs.is_any_type()) {
        return false;
    }

    if (this->is_frame_type()) {
        if (rhs.is_frame_type()) {
            return this->get<frame>() < rhs.get<frame>();
        } else if (rhs.is_range_type()) {
            return true;
        }
    } else if (this->is_range_type()) {
        if (rhs.is_frame_type()) {
            return false;
        } else if (rhs.is_range_type()) {
            return this->get<range>() < rhs.get<range>();
        }
    }

    throw "unreachable code.";
}

std::type_info const &proc::time::type() const {
    return this->_impl->type();
}

bool proc::time::is_range_type() const {
    return this->type() == typeid(range);
}

bool proc::time::is_frame_type() const {
    return this->type() == typeid(frame);
}

bool proc::time::is_any_type() const {
    return this->type() == typeid(any);
}

bool proc::time::is_contain(time const &rhs) const {
    if (this->is_range_type()) {
        auto const &range = this->get<time::range>();
        if (rhs.is_range_type()) {
            return range.is_contain(rhs.get<time::range>());
        } else if (rhs.is_frame_type()) {
            return range.is_contain(rhs.get<time::frame>());
        } else if (rhs.is_any_type()) {
            return range.is_contain(rhs.get<time::any>());
        }

        throw "unreachable code.";
    } else {
        return false;
    }
}

template <typename T>
typename T::type const &proc::time::get() const {
    if (auto ip = std::dynamic_pointer_cast<impl<T>>(this->_impl)) {
        return ip->_value;
    }

    throw "unreachable code.";
}

template proc::time::range::type const &proc::time::get<proc::time::range>() const;
template proc::time::frame::type const &proc::time::get<proc::time::frame>() const;
template proc::time::any::type const &proc::time::get<proc::time::any>() const;

proc::time proc::time::offset(frame_index_t const &offset) const {
    if (offset == 0 || this->is_any_type()) {
        return *this;
    } else if (this->is_frame_type()) {
        return make_frame_time(this->get<time::frame>() + offset);
    } else if (this->is_range_type()) {
        return time{this->get<time::range>().offset(offset)};
    } else {
        throw "unreachable code.";
    }
}

proc::time::operator bool() const {
    return this->_impl != nullptr;
}

bool proc::time::operator==(proc::time const &rhs) const {
    return this->_impl->is_equal(rhs._impl);
}

bool proc::time::operator!=(proc::time const &rhs) const {
    return !(*this == rhs);
}

std::string yas::to_string(proc::time const &time) {
    if (time.is_range_type()) {
        return yas::to_string(time.get<proc::time::range>());
    } else if (time.is_frame_type()) {
        return std::to_string(time.get<proc::time::frame>());
    } else if (time.is_any_type()) {
        return "any";
    } else {
        throw "unreachable code.";
    }
}

std::string yas::to_string(proc::time::range const &range) {
    return "{" + std::to_string(range.frame) + ", " + std::to_string(range.length) + "}";
}

std::ostream &operator<<(std::ostream &os, yas::proc::time const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::proc::time::range const &value) {
    os << to_string(value);
    return os;
}

#pragma mark - private

std::shared_ptr<proc::time::impl<proc::time::any>> const &proc::time::any_impl_ptr() {
    static auto impl_ptr = std::make_shared<time::impl<time::any>>(time::any{});
    return impl_ptr;
}

#pragma mark - make

proc::time proc::make_range_time(frame_index_t const frame, length_t const length) {
    return proc::time{frame, length};
}

proc::time proc::make_frame_time(frame_index_t const frame) {
    return proc::time{frame};
}

proc::time proc::make_any_time() {
    return proc::time{};
}
