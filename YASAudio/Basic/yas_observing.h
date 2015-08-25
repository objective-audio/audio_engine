//
//  yas_observing.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <functional>
#include <string>
#include <map>
#include <memory>
#include <vector>
#include <experimental/optional>
#include <initializer_list>

namespace yas
{
    template <typename K, typename T>
    class subject;

    template <typename K, typename T = std::nullptr_t>
    class observer
    {
       public:
        using sptr = std::shared_ptr<observer<K, T>>;
        using handler_f = std::function<void(const K &, const T &)>;

        static sptr create();

        ~observer();

        bool operator==(const observer<K, T> &) const;
        bool operator!=(const observer<K, T> &) const;

        void add_handler(subject<K, T> &subject, const K &key, const handler_f &handler);
        void remove_handler(subject<K, T> &subject, const K &key);

        void add_wild_card_handler(subject<K, T> &subject, const handler_f &handler);
        void remove_wild_card_handler(subject<K, T> &subject);

       private:
        class handler_holder;
        std::map<const subject<K, T> *, handler_holder> _handlers;

        std::weak_ptr<observer<K, T>> _weak_this;

        observer();

        observer(const observer<K, T> &) = delete;
        observer(const observer<K, T> &&) = delete;
        observer &operator=(const observer<K, T> &) = delete;
        observer &operator=(const observer<K, T> &&) = delete;

        void _call_handler(const subject<K, T> &subject, const K &key, const T &object);
        void _call_wild_card_handler(const subject<K, T> &subject, const K &key, const T &object);

        friend subject<K, T>;
    };

    template <typename K, typename T>
    static auto make_observer(const subject<K, T> &) -> typename observer<K, T>::sptr;

    template <typename K, typename T>
    static auto make_subject_dispatcher(const subject<K, T> &source_subject,
                                        const std::initializer_list<subject<K, T> *> &destination_subjects) ->
        typename observer<K, T>::sptr;

    template <typename K, typename T = std::nullptr_t>
    class subject
    {
       public:
        using sptr = std::shared_ptr<subject<K, T>>;

        static sptr create();

        subject();
        ~subject();

        bool operator==(const subject<K, T> &) const;
        bool operator!=(const subject<K, T> &) const;

        void notify(const K &key) const;
        void notify(const K &key, const T &object) const;

       private:
        using observers_vec = std::vector<std::weak_ptr<observer<K, T>>>;
        using observers_map = std::map<const std::experimental::optional<K>, observers_vec>;
        observers_map _observers;

        subject(const subject<K, T> &) = delete;
        subject(const subject<K, T> &&) = delete;
        subject &operator=(const subject<K, T> &) = delete;
        subject &operator=(const subject<K, T> &&) = delete;

        void _add_observer(typename observer<K, T>::sptr &observer, const std::experimental::optional<K> &key);
        void _remove_observer(const typename observer<K, T>::sptr &observer, const std::experimental::optional<K> &key);
        void _remove_observer(const typename observer<K, T>::sptr &observer);

        friend observer<K, T>;
    };
}

#include "yas_observing_private.h"
