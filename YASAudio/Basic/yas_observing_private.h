//
//  yas_observing_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
#pragma mark - observer

    template <typename K, typename T>
    class observer<K, T>::handler_holder
    {
        std::map<const std::experimental::optional<K>, const handler_function> functions;

       public:
        void add_handler(const std::experimental::optional<K> &key, const handler_function &handler)
        {
            functions.insert(std::make_pair(key, handler));
        }

        void remove_handler(const std::experimental::optional<K> &key)
        {
            if (functions.count(key) > 0) {
                functions.erase(key);
            }
        }

        void call_handler(const K &key, const T &sender) const
        {
            if (functions.count(key) > 0) {
                functions.at(key)(key, sender);
            }
        }

        void call_wild_card_handler(const K &key, const T &sender) const
        {
            if (functions.count(std::experimental::nullopt)) {
                functions.at(std::experimental::nullopt)(key, sender);
            }
        }

        size_t size() const
        {
            return functions.size();
        }
    };

    template <typename K, typename T>
    typename observer<K, T>::shared_ptr observer<K, T>::create()
    {
        return shared_ptr(new observer<K, T>());
    }

    template <typename K, typename T>
    observer<K, T>::observer()
    {
    }

    template <typename K, typename T>
    observer<K, T>::~observer()
    {
    }

    template <typename K, typename T>
    bool observer<K, T>::operator==(const observer<K, T> &other) const
    {
        return this == &other;
    }

    template <typename K, typename T>
    bool observer<K, T>::operator!=(const observer<K, T> &other) const
    {
        return this != &other;
    }

    template <typename K, typename T>
    void observer<K, T>::add_handler(subject<K, T> &subject, const K &key, const handler_function &handler)
    {
        auto subject_ptr = &subject;
        if (_handlers.count(subject_ptr) == 0) {
            _handlers.insert(std::make_pair(&subject, typename yas::observer<K, T>::handler_holder()));
        };
        _handlers.at(&subject).add_handler(key, handler);
        subject.add_observer(*this, key);
    }

    template <typename K, typename T>
    void observer<K, T>::remove_handler(subject<K, T> &subject, const K &key)
    {
        if (_handlers.count(&subject) > 0) {
            auto &handler_holder = _handlers.at(&subject);
            handler_holder.remove_handler(key);
            if (handler_holder.size() == 0) {
                _handlers.erase(&subject);
            }
        }
        subject.remove_observer(*this, key);
    }

    template <typename K, typename T>
    void observer<K, T>::add_wild_card_handler(subject<K, T> &subject, const handler_function &handler)
    {
        auto subject_ptr = &subject;
        if (_handlers.count(subject_ptr) == 0) {
            _handlers.insert(std::make_pair(&subject, typename yas::observer<K, T>::handler_holder()));
        };
        _handlers.at(&subject).add_handler(std::experimental::nullopt, handler);
        subject.add_observer(*this, std::experimental::nullopt);
    }

    template <typename K, typename T>
    void observer<K, T>::remove_wild_card_handler(subject<K, T> &subject)
    {
        if (_handlers.count(&subject) > 0) {
            auto &handler_holder = _handlers.at(&subject);
            handler_holder.remove_handler(std::experimental::nullopt);
            if (handler_holder.size() == 0) {
                _handlers.erase(&subject);
            }
        }
        subject.remove_observer(*this, std::experimental::nullopt);
    }

    template <typename K, typename T>
    void observer<K, T>::call_handler(const subject<K, T> &subject, const K &key, const T &object)
    {
        if (_handlers.count(&subject) > 0) {
            _handlers.at(&subject).call_handler(key, object);
        }
    }

    template <typename K, typename T>
    void observer<K, T>::call_wild_card_handler(const subject<K, T> &subject, const K &key, const T &object)
    {
        if (_handlers.count(&subject) > 0) {
            _handlers.at(&subject).call_wild_card_handler(key, object);
        }
    }

    template <typename K, typename T>
    auto make_observer(const subject<K, T> &) -> typename observer<K, T>::shared_ptr
    {
        return observer<K, T>::create();
    }

    template <typename K, typename T>
    auto make_subject_dispatcher(const subject<K, T> &source,
                                 const std::initializer_list<subject<K, T> *> &destinations) ->
        typename observer<K, T>::shared_ptr
    {
        auto observer = make_observer(source);
        auto handler = [&source](const auto &method, const auto &value) { source.notify(method, value); };

        for (const auto &destination : destinations) {
            observer->add_wild_card_handler(*destination, handler);
        }

        return observer;
    }

#pragma mark - subject

    template <typename K, typename T>
    typename subject<K, T>::subject_ptr subject<K, T>::create()
    {
        return subject_ptr(new subject<K, T>());
    }

    template <typename K, typename T>
    subject<K, T>::subject()
    {
    }

    template <typename K, typename T>
    subject<K, T>::~subject()
    {
    }

    template <typename K, typename T>
    bool subject<K, T>::operator==(const subject<K, T> &other) const
    {
        return this == &other;
    }

    template <typename K, typename T>
    bool subject<K, T>::operator!=(const subject<K, T> &other) const
    {
        return this != &other;
    }

    template <typename K, typename T>
    void subject<K, T>::notify(const K &key, const T &object) const
    {
        if (_observers.count(key)) {
            for (auto &observer : _observers.at(key)) {
                if (auto shared_observer = observer.lock()) {
                    shared_observer->call_handler(*this, key, object);
                }
            }
        }
        if (_observers.count(std::experimental::nullopt)) {
            for (auto &observer : _observers.at(std::experimental::nullopt)) {
                if (auto shared_observer = observer.lock()) {
                    shared_observer->call_wild_card_handler(*this, key, object);
                }
            }
        }
    }

    template <typename K, typename T>
    void subject<K, T>::add_observer(observer<K, T> &observer, const std::experimental::optional<K> &key)
    {
        if (_observers.count(key) == 0) {
            _observers.insert(std::make_pair(key, observers_vector()));
        }

        auto &vector = _observers.at(key);
        vector.push_back(observer.shared_from_this());
    }

    template <typename K, typename T>
    void subject<K, T>::remove_observer(const observer<K, T> &observer, const std::experimental::optional<K> &key)
    {
        if (_observers.count(key) > 0) {
            auto &vector = _observers.at(key);

            auto it = vector.begin();
            while (it != vector.end()) {
                if (auto shared_observer = it->lock()) {
                    if (*shared_observer == observer) {
                        it = vector.erase(it);
                    } else {
                        ++it;
                    }
                } else {
                    it = vector.erase(it);
                }
            }
        }
    }

    template <typename K, typename T>
    void subject<K, T>::remove_observer(const observer<K, T> &observer)
    {
        for (auto &pair : _observers) {
            remove_observer(observer, pair.first);
        }
    }
}