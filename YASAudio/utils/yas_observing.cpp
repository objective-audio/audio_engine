//
//  yas_observing.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_observing.h"
#include "yas_audio_types.h"
#include "yas_stl_utils.h"
#include <unordered_map>
#include <unordered_set>
#include <experimental/optional>

using namespace yas;

namespace yas
{
    using string_opt = std::experimental::optional<std::string>;
}

#pragma mark - impl

class observer::impl : public base::impl
{
   public:
    class handler_holder
    {
        std::unordered_map<string_opt, const handler_f> functions;

       public:
        void add_handler(const string_opt &key, const handler_f &handler)
        {
            functions.insert(std::make_pair(key, handler));
        }

        void remove_handler(const string_opt &key)
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

    std::unordered_map<const subject *, handler_holder> handlers;

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
    using observer_set_t = std::unordered_set<weak<observer>>;
    using observers_t = std::unordered_map<string_opt, observer_set_t>;
    observers_t observers;

    void add_observer(const observer &obs, const string_opt &key)
    {
        if (observers.count(key) == 0) {
            observers.insert(std::make_pair(key, observer_set_t()));
        }

        auto &set = observers.at(key);
        set.insert(weak<observer>(obs));
    }

    void remove_observer(const observer &observer, const string_opt &key)
    {
        if (observers.count(key) > 0) {
            auto &set = observers.at(key);

            erase_if(set, [&observer](const auto &weak_observer) {
                if (auto locked_observer = weak_observer.lock()) {
                    if (observer == locked_observer) {
                        return true;
                    }
                }
                return false;
            });

            if (set.size() == 0) {
                observers.erase(key);
            }
        }
    }

    void remove_observer(const uintptr_t observer_key)
    {
        erase_if(observers, [&observer_key](auto &pair) {
            auto &set = pair.second;

            erase_if(set, [&observer_key](const auto &weak_observer) {
                if (auto strong_observer = weak_observer.lock()) {
                    if (strong_observer.identifier() == observer_key) {
                        return true;
                    }
                } else {
                    return true;
                }
                return false;
            });

            return set.size() == 0;
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

void observer::add_handler(subject &subject, const std::string &key, const handler_f &handler) const
{
    auto imp = impl_ptr<impl>();
    auto subject_ptr = &subject;
    if (imp->handlers.count(subject_ptr) == 0) {
        imp->handlers.insert(std::make_pair(&subject, yas::observer::impl::handler_holder()));
    };
    imp->handlers.at(&subject).add_handler(key, handler);

    subject._impl->add_observer(*this, key);
}

void observer::remove_handler(subject &subject, const std::string &key) const
{
    auto imp = impl_ptr<impl>();
    if (imp->handlers.count(&subject) > 0) {
        auto &handler_holder = imp->handlers.at(&subject);
        handler_holder.remove_handler(key);
        if (handler_holder.size() == 0) {
            imp->handlers.erase(&subject);
        }
    }
    subject._impl->remove_observer(*this, key);
}

void observer::add_wild_card_handler(subject &subject, const handler_f &handler) const
{
    auto imp = impl_ptr<impl>();
    auto subject_ptr = &subject;
    if (imp->handlers.count(subject_ptr) == 0) {
        imp->handlers.insert(std::make_pair(&subject, yas::observer::impl::handler_holder()));
    };
    imp->handlers.at(&subject).add_handler(nullopt, handler);
    subject._impl->add_observer(*this, nullopt);
}

void observer::remove_wild_card_handler(subject &subject) const
{
    auto imp = impl_ptr<impl>();
    if (imp->handlers.count(&subject) > 0) {
        auto &handler_holder = imp->handlers.at(&subject);
        handler_holder.remove_handler(nullopt);
        if (handler_holder.size() == 0) {
            imp->handlers.erase(&subject);
        }
    }
    subject._impl->remove_observer(*this, nullopt);
}

void observer::clear() const
{
    auto id = identifier();
    auto imp = impl_ptr<impl>();
    for (auto &pair : imp->handlers) {
        auto &subject_ptr = pair.first;
        subject_ptr->_impl->remove_observer(id);
    }
    imp->handlers.clear();
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
        for (auto &weak_observer : pair.second) {
            if (auto observer = weak_observer.lock()) {
                observer.impl_ptr<observer::impl>()->handlers.erase(this);
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
        for (auto &weak_observer : _impl->observers.at(key)) {
            if (auto observer = weak_observer.lock()) {
                observer.impl_ptr<observer::impl>()->call_handler(*this, key, object);
            }
        }
    }
    if (_impl->observers.count(nullopt)) {
        for (auto &weak_observer : _impl->observers.at(nullopt)) {
            if (auto observer = weak_observer.lock()) {
                observer.impl_ptr<observer::impl>()->call_wild_card_handler(*this, key, object);
            }
        }
    }
}
