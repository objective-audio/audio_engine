//
//  yas_observing.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_base.h"
#include <functional>
#include <string>
#include <initializer_list>

namespace yas {
template <typename T>
class subject;

template <typename T = std::nullptr_t>
class observer : public base {
    using super_class = base;
    class impl;

   public:
    using handler_f = std::function<void(const std::string &, const T &)>;

    observer();
    observer(std::nullptr_t);
    ~observer();

    observer(const observer &) = default;
    observer(observer &&) = default;
    observer &operator=(const observer &) = default;
    observer &operator=(observer &&) = default;

    void add_handler(subject<T> &subject, const std::string &key, const handler_f &handler);
    void remove_handler(subject<T> &subject, const std::string &key);

    void add_wild_card_handler(subject<T> &subject, const handler_f &handler);
    void remove_wild_card_handler(subject<T> &subject);

    void clear();

    friend subject<T>;
};

template <typename T = std::nullptr_t>
class subject {
   public:
    subject();
    ~subject();

    bool operator==(const subject &) const;
    bool operator!=(const subject &) const;

    void notify(const std::string &key) const;
    void notify(const std::string &key, const T &object) const;

    observer<T> make_observer(const std::string &key, const typename observer<T>::handler_f &handler);
    observer<T> make_wild_card_observer(const typename observer<T>::handler_f &handler);

   private:
    class impl;
    std::unique_ptr<impl> _impl;

    subject(const subject &) = delete;
    subject(subject &&) = delete;
    subject &operator=(const subject &) = delete;
    subject &operator=(subject &&) = delete;

    friend observer<T>;
};

template <typename T>
observer<T> make_subject_dispatcher(const subject<T> &source_subject,
                                    const std::initializer_list<subject<T> *> &destination_subjects);
}

template <typename T>
struct std::hash<yas::observer<T>> {
    std::size_t operator()(yas::observer<T> const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

template <typename T>
struct std::hash<yas::weak<yas::observer<T>>> {
    std::size_t operator()(yas::weak<yas::observer<T>> const &weak_key) const {
        auto key = weak_key.lock();
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#include "yas_observing_private.h"
