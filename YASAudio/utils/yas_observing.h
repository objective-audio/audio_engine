//
//  yas_observing.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_any.h"
#include "yas_base.h"
#include <functional>
#include <string>
#include <initializer_list>

namespace yas
{
    class observer;
    class subject;

    class observer : public base
    {
        using super_class = base;
        class impl;

       public:
        using handler_f = std::function<void(const std::string &, const yas::any &)>;

        observer();
        explicit observer(std::nullptr_t);
        ~observer();

        observer(const observer &) = default;
        observer(observer &&) = default;
        observer &operator=(const observer &) = default;
        observer &operator=(observer &&) = default;

        void add_handler(subject &subject, const std::string &key, const handler_f &handler) const;
        void remove_handler(subject &subject, const std::string &key) const;

        void add_wild_card_handler(subject &subject, const handler_f &handler) const;
        void remove_wild_card_handler(subject &subject) const;

        void clear() const;

        friend subject;
    };

    observer make_subject_dispatcher(const subject &source_subject,
                                     const std::initializer_list<subject *> &destination_subjects);

    class subject
    {
       public:
        subject();
        ~subject();

        bool operator==(const subject &) const;
        bool operator!=(const subject &) const;

        void notify(const std::string &key) const;
        void notify(const std::string &key, const yas::any &object) const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        subject(const subject &) = delete;
        subject(subject &&) = delete;
        subject &operator=(const subject &) = delete;
        subject &operator=(subject &&) = delete;

        friend observer;
    };
}

template <>
struct std::hash<yas::observer> {
    std::size_t operator()(yas::observer const &key) const
    {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

template <>
struct std::hash<yas::weak<yas::observer>> {
    std::size_t operator()(yas::weak<yas::observer> const &weak_key) const
    {
        auto key = weak_key.lock();
        return std::hash<uintptr_t>()(key.identifier());
    }
};
