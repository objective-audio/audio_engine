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

    template <typename K, typename T>
    class observer : public std::enable_shared_from_this<observer<K, T>>
    {
       public:
        using shared_ptr = std::shared_ptr<observer<K, T>>;
        using handler_function = std::function<void(const K &, const T &)>;

        static shared_ptr create();

        ~observer();

        bool operator==(const observer<K, T> &) const;
        bool operator!=(const observer<K, T> &) const;

        void add_handler(subject<K, T> &subject, const K &key, const handler_function &handler);
        void remove_handler(subject<K, T> &subject, const K &key);

        void add_wild_card_handler(subject<K, T> &subject, const handler_function &handler);
        void remove_wild_card_handler(subject<K, T> &subject);

       private:
        class handler_holder;
        std::map<const subject<K, T> *, handler_holder> _handlers;

        observer();

        observer(const observer<K, T> &) = delete;
        observer(const observer<K, T> &&) = delete;
        observer &operator=(const observer<K, T> &) = delete;
        observer &operator=(const observer<K, T> &&) = delete;

        void call_handler(const subject<K, T> &subject, const K &key, const T &object);
        void call_wild_card_handler(const subject<K, T> &subject, const K &key, const T &object);

        friend subject<K, T>;
    };

    template <typename K, typename T>
    static auto make_observer(const subject<K, T> &) -> typename observer<K, T>::shared_ptr;

    template <typename K, typename T>
    static auto make_subject_dispatcher(const subject<K, T> &source_subject,
                                        const std::initializer_list<subject<K, T> *> &destination_subjects) ->
        typename observer<K, T>::shared_ptr;

    template <typename K, typename T>
    class subject
    {
       public:
        using subject_ptr = std::shared_ptr<subject<K, T>>;

        static subject_ptr create();

        subject();
        ~subject();

        bool operator==(const subject<K, T> &) const;
        bool operator!=(const subject<K, T> &) const;

        void notify(const K &key, const T &object) const;

       private:
        using observers_vector = std::vector<std::weak_ptr<observer<K, T>>>;
        using observers_map = std::map<const std::experimental::optional<K>, observers_vector>;
        observers_map _observers;

        subject(const subject<K, T> &) = delete;
        subject(const subject<K, T> &&) = delete;
        subject &operator=(const subject<K, T> &) = delete;
        subject &operator=(const subject<K, T> &&) = delete;

        void add_observer(observer<K, T> &observer, const std::experimental::optional<K> &key);
        void remove_observer(const observer<K, T> &observer, const std::experimental::optional<K> &key);
        void remove_observer(const observer<K, T> &observer);

        friend observer<K, T>;
    };
}

#include "yas_observing_private.h"
