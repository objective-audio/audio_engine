//
//  yas_observing.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_observing.h"
#include "yas_audio_types.h"
#include "yas_stl_utils.h"
#include <list>
#include <experimental/optional>

using namespace yas;

#pragma mark - impl

class observer::impl : public base::impl
{
   public:
    class handler_holder
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

    std::map<const subject *, handler_holder> handlers;

    void call_handler(const subject &subject, const std::string &key, const yas::any &object)
    {
        if (handlers.count(&subject) > 0) {
            handlers.at(&subject).call_handler(key, object);
        }
    }

    void call_wild_card_handler(const subject &subject, const std::string &key, const yas::any &object)
    {
        if (handlers.count(&subject) > 0) {
            handlers.at(&subject).call_wild_card_handler(key, object);
        }
    }
};

class subject::impl
{
   public:
    using observer_map_t = std::map<uintptr_t, weak<observer>>;
    using observers_t = std::map<const std::experimental::optional<std::string>, observer_map_t>;
    observers_t observers;

    void add_observer(observer &obs, const std::experimental::optional<std::string> &key)
    {
        if (observers.count(key) == 0) {
            observers.insert(std::make_pair(key, observer_map_t()));
        }

        auto &map = observers.at(key);
        map.insert(std::make_pair(obs.identifier(), weak<observer>(obs)));
    }

    void remove_observer(const uintptr_t observer_key, const std::experimental::optional<std::string> &key)
    {
        if (observers.count(key) > 0) {
            auto &map = observers.at(key);

            erase_if(map, [&observer_key](const auto &observer_pair) {
                if (observer_key == observer_pair.first) {
                    return true;
                }
                return false;
            });

            if (map.size() == 0) {
                observers.erase(key);
            }
        }
    }

    void remove_observer(const uintptr_t observer_key)
    {
        erase_if(observers, [&observer_key](auto &pair) {
            auto &map = pair.second;

            erase_if(map, [&observer_key](const auto &observer_pair) {
                if (observer_key == observer_pair.first) {
                    return true;
                }
                return false;
            });

            return map.size() == 0;
        });
    }
};

#pragma mark - observer

observer::observer() : super_class(std::make_shared<impl>())
{
}

observer::observer(std::nullptr_t) : super_class(nullptr)
{
}

observer::~observer()
{
    if (impl_ptr() && impl_ptr().unique()) {
        clear();
        impl_ptr().reset();
    }
}

void observer::add_handler(subject &subject, const std::string &key, const handler_f &handler)
{
    auto impl = _impl_ptr();
    auto subject_ptr = &subject;
    if (impl->handlers.count(subject_ptr) == 0) {
        impl->handlers.insert(std::make_pair(&subject, yas::observer::impl::handler_holder()));
    };
    impl->handlers.at(&subject).add_handler(key, handler);
    subject._impl->add_observer(*this, key);
}

void observer::remove_handler(subject &subject, const std::string &key)
{
    auto impl = _impl_ptr();
    if (impl->handlers.count(&subject) > 0) {
        auto &handler_holder = impl->handlers.at(&subject);
        handler_holder.remove_handler(key);
        if (handler_holder.size() == 0) {
            impl->handlers.erase(&subject);
        }
    }
    subject._impl->remove_observer(identifier(), key);
}

void observer::add_wild_card_handler(subject &subject, const handler_f &handler)
{
    auto impl = _impl_ptr();
    auto subject_ptr = &subject;
    if (impl->handlers.count(subject_ptr) == 0) {
        impl->handlers.insert(std::make_pair(&subject, yas::observer::impl::handler_holder()));
    };
    impl->handlers.at(&subject).add_handler(nullopt, handler);
    subject._impl->add_observer(*this, nullopt);
}

void observer::remove_wild_card_handler(subject &subject)
{
    auto impl = _impl_ptr();
    if (impl->handlers.count(&subject) > 0) {
        auto &handler_holder = impl->handlers.at(&subject);
        handler_holder.remove_handler(nullopt);
        if (handler_holder.size() == 0) {
            impl->handlers.erase(&subject);
        }
    }
    subject._impl->remove_observer(identifier(), nullopt);
}

void observer::clear()
{
    auto id = identifier();
    auto impl = _impl_ptr();
    for (auto &pair : impl->handlers) {
        auto &subject_ptr = pair.first;
        subject_ptr->_impl->remove_observer(id);
    }
    impl->handlers.clear();
}

std::shared_ptr<observer::impl> observer::_impl_ptr() const
{
    return impl_ptr<observer::impl>();
}

observer yas::make_subject_dispatcher(const subject &source, const std::initializer_list<subject *> &destinations)
{
    yas::observer observer;
    auto handler = [&source](const auto &method, const auto &value) { source.notify(method, value); };

    for (const auto &destination : destinations) {
        observer.add_wild_card_handler(*destination, handler);
    }

    return observer;
}

#pragma mark - subject

subject::subject() : _impl(std::make_unique<impl>())
{
}

subject::~subject()
{
    for (auto &pair : _impl->observers) {
        for (auto &observer_pair : pair.second) {
            if (auto observer = observer_pair.second.lock()) {
                observer._impl_ptr()->handlers.erase(this);
            }
        }
    }
}

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
    if (_impl->observers.count(key)) {
        for (auto &observer_pair : _impl->observers.at(key)) {
            if (auto observer = observer_pair.second.lock()) {
                observer._impl_ptr()->call_handler(*this, key, object);
            }
        }
    }
    if (_impl->observers.count(nullopt)) {
        for (auto &observer_pair : _impl->observers.at(nullopt)) {
            if (auto observer = observer_pair.second.lock()) {
                observer._impl_ptr()->call_wild_card_handler(*this, key, object);
            }
        }
    }
}
