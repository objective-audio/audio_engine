//
//  yas_observing.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_observing.h"
#include "yas_audio_types.h"

using namespace yas;

#pragma mark - observer

class observer::handler_holder
{
    std::map<const std::experimental::optional<std::string>, const handler_f> functions;

   public:
    void add_handler(const std::experimental::optional<std::string> &key, const handler_f &handler)
    {
        functions.insert(std::make_pair(key, handler));
    }

    void remove_handler(const std::experimental::optional<std::string> &key)
    {
        if (functions.count(key) > 0) {
            functions.erase(key);
        }
    }

    void call_handler(const std::string &key, const yas::any &sender) const
    {
        if (functions.count(key) > 0) {
            functions.at(key)(key, sender);
        }
    }

    void call_wild_card_handler(const std::string &key, const yas::any &sender) const
    {
        if (functions.count(nullopt)) {
            functions.at(nullopt)(key, sender);
        }
    }

    size_t size() const
    {
        return functions.size();
    }
};

observer::sptr observer::create()
{
    auto ptr = sptr(new observer());
    ptr->_weak_this = ptr;
    return ptr;
}

bool observer::operator==(const observer &other) const
{
    return this == &other;
}

bool observer::operator!=(const observer &other) const
{
    return this != &other;
}

void observer::add_handler(subject &subject, const std::string &key, const handler_f &handler)
{
    auto subject_ptr = &subject;
    if (_handlers.count(subject_ptr) == 0) {
        _handlers.insert(std::make_pair(&subject, yas::observer::handler_holder()));
    };
    _handlers.at(&subject).add_handler(key, handler);
    if (auto shared_observer = _weak_this.lock()) {
        subject._add_observer(shared_observer, key);
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : _weak_this.lock() failed.");
    }
}

void observer::remove_handler(subject &subject, const std::string &key)
{
    if (_handlers.count(&subject) > 0) {
        auto &handler_holder = _handlers.at(&subject);
        handler_holder.remove_handler(key);
        if (handler_holder.size() == 0) {
            _handlers.erase(&subject);
        }
    }

    if (auto shared_observer = _weak_this.lock()) {
        subject._remove_observer(shared_observer, key);
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : _weak_this.lock() failed.");
    }
}

void observer::add_wild_card_handler(subject &subject, const handler_f &handler)
{
    auto subject_ptr = &subject;
    if (_handlers.count(subject_ptr) == 0) {
        _handlers.insert(std::make_pair(&subject, yas::observer::handler_holder()));
    };
    _handlers.at(&subject).add_handler(nullopt, handler);

    if (auto shared_observer = _weak_this.lock()) {
        subject._add_observer(shared_observer, nullopt);
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : _weak_this.lock() failed.");
    }
}

void observer::remove_wild_card_handler(subject &subject)
{
    if (_handlers.count(&subject) > 0) {
        auto &handler_holder = _handlers.at(&subject);
        handler_holder.remove_handler(nullopt);
        if (handler_holder.size() == 0) {
            _handlers.erase(&subject);
        }
    }

    if (auto shared_observer = _weak_this.lock()) {
        subject._remove_observer(shared_observer, nullopt);
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : _weak_this.lock() failed.");
    }
}

void observer::_call_handler(const subject &subject, const std::string &key, const yas::any &object)
{
    if (_handlers.count(&subject) > 0) {
        _handlers.at(&subject).call_handler(key, object);
    }
}

void observer::_call_wild_card_handler(const subject &subject, const std::string &key, const yas::any &object)
{
    if (_handlers.count(&subject) > 0) {
        _handlers.at(&subject).call_wild_card_handler(key, object);
    }
}

observer::sptr yas::make_subject_dispatcher(const subject &source, const std::initializer_list<subject *> &destinations)
{
    auto observer = observer::create();
    auto handler = [&source](const auto &method, const auto &value) { source.notify(method, value); };

    for (const auto &destination : destinations) {
        observer->add_wild_card_handler(*destination, handler);
    }

    return observer;
}

#pragma mark - subject

bool subject::operator==(const subject &other) const
{
    return this == &other;
}

bool subject::operator!=(const subject &other) const
{
    return this != &other;
}

void subject::notify(const std::string &key) const
{
    notify(key, nullptr);
}

void subject::notify(const std::string &key, const yas::any &object) const
{
    if (_observers.count(key)) {
        for (auto &observer : _observers.at(key)) {
            if (auto shared_observer = observer.lock()) {
                shared_observer->_call_handler(*this, key, object);
            }
        }
    }
    if (_observers.count(nullopt)) {
        for (auto &observer : _observers.at(nullopt)) {
            if (auto shared_observer = observer.lock()) {
                shared_observer->_call_wild_card_handler(*this, key, object);
            }
        }
    }
}

void subject::_add_observer(observer::sptr &observer, const std::experimental::optional<std::string> &key)
{
    if (_observers.count(key) == 0) {
        _observers.insert(std::make_pair(key, observers_vector_t()));
    }

    auto &vector = _observers.at(key);
    vector.push_back(observer);
}

void subject::_remove_observer(const observer::sptr &observer, const std::experimental::optional<std::string> &key)
{
    if (_observers.count(key) > 0) {
        auto &vector = _observers.at(key);

        auto it = vector.begin();
        while (it != vector.end()) {
            if (auto shared_observer = it->lock()) {
                if (shared_observer == observer) {
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

void subject::_remove_observer(const observer::sptr &observer)
{
    for (auto &pair : _observers) {
        _remove_observer(observer, pair.first);
    }
}
