//
//  yas_observing.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_any.h"
#include <functional>
#include <string>
#include <map>
#include <memory>
#include <vector>
#include <experimental/optional>
#include <initializer_list>

namespace yas
{
    class subject;

    class observer
    {
       public:
        using sptr = std::shared_ptr<observer>;
        using handler_f = std::function<void(const std::string &, const yas::any &)>;

        static sptr create();

        ~observer() = default;

        bool operator==(const observer &) const;
        bool operator!=(const observer &) const;

        void add_handler(subject &subject, const std::string &key, const handler_f &handler);
        void remove_handler(subject &subject, const std::string &key);

        void add_wild_card_handler(subject &subject, const handler_f &handler);
        void remove_wild_card_handler(subject &subject);

       private:
        class handler_holder;
        std::map<const subject *, handler_holder> _handlers;

        std::weak_ptr<observer> _weak_this;

        observer() = default;

        observer(const observer &) = delete;
        observer(observer &&) = delete;
        observer &operator=(const observer &) = delete;
        observer &operator=(observer &&) = delete;

        void _call_handler(const subject &subject, const std::string &key, const yas::any &object);
        void _call_wild_card_handler(const subject &subject, const std::string &key, const yas::any &object);

        friend subject;
    };

    observer::sptr make_subject_dispatcher(const subject &source_subject,
                                           const std::initializer_list<subject *> &destination_subjects);

    class subject
    {
       public:
        subject() = default;
        ~subject() = default;

        bool operator==(const subject &) const;
        bool operator!=(const subject &) const;

        void notify(const std::string &key) const;
        void notify(const std::string &key, const yas::any &object) const;

       private:
        using observers_vector_t = std::vector<std::weak_ptr<observer>>;
        using observers_map_t = std::map<const std::experimental::optional<std::string>, observers_vector_t>;
        observers_map_t _observers;

        subject(const subject &) = delete;
        subject(subject &&) = delete;
        subject &operator=(const subject &) = delete;
        subject &operator=(subject &&) = delete;

        void _add_observer(typename observer::sptr &observer, const std::experimental::optional<std::string> &key);
        void _remove_observer(const typename observer::sptr &observer,
                              const std::experimental::optional<std::string> &key);
        void _remove_observer(const typename observer::sptr &observer);

        friend observer;
    };
}
