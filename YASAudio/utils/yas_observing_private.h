//
//  yas_observing_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_stl_utils.h"
#include <unordered_map>
#include <unordered_set>
#include <experimental/optional>

namespace yas {
using string_opt = std::experimental::optional<std::string>;

#pragma mark - impl

template <typename T>
class observer<T>::impl : public base::impl {
   public:
    class handler_holder {
        std::unordered_map<string_opt, const handler_f> functions;

       public:
        void add_handler(const string_opt &key, const handler_f &handler) {
            functions.insert(std::make_pair(key, handler));
        }

        void remove_handler(const string_opt &key) {
            if (functions.count(key) > 0) {
                functions.erase(key);
            }
        }

        void call_handler(const std::string &key, const T &sender) const {
            if (functions.count(key) > 0) {
                functions.at(key)(key, sender);
            }
        }

        void call_wild_card_handler(const std::string &key, const T &sender) const {
            if (functions.count(nullopt)) {
                functions.at(nullopt)(key, sender);
            }
        }

        size_t size() const {
            return functions.size();
        }
    };

    std::unordered_map<const subject<T> *, handler_holder> handlers;

    void call_handler(const subject<T> &subject, const std::string &key, const T &object) {
        if (handlers.count(&subject) > 0) {
            handlers.at(&subject).call_handler(key, object);
        }
    }

    void call_wild_card_handler(const subject<T> &subject, const std::string &key, const T &object) {
        if (handlers.count(&subject) > 0) {
            handlers.at(&subject).call_wild_card_handler(key, object);
        }
    }
};

template <typename T>
class subject<T>::impl {
   public:
    using observer_set_t = std::unordered_set<weak<observer<T>>>;
    using observers_t = std::unordered_map<string_opt, observer_set_t>;
    observers_t observers;

    void add_observer(const observer<T> &obs, const string_opt &key) {
        if (observers.count(key) == 0) {
            observers.insert(std::make_pair(key, observer_set_t()));
        }

        auto &set = observers.at(key);
        set.insert(weak<observer<T>>(obs));
    }

    void remove_observer(const observer<T> &observer, const string_opt &key) {
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

    void remove_observer(const uintptr_t observer_key) {
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

template <typename T>
observer<T>::observer()
    : super_class(std::make_shared<impl>()) {
}

template <typename T>
observer<T>::observer(std::nullptr_t)
    : super_class(nullptr) {
}

template <typename T>
observer<T>::~observer() {
    if (impl_ptr() && impl_ptr().unique()) {
        clear();
        impl_ptr().reset();
    }
}

template <typename T>
void observer<T>::add_handler(subject<T> &subject, const std::string &key, const handler_f &handler) {
    auto imp = impl_ptr<impl>();
    auto subject_ptr = &subject;
    if (imp->handlers.count(subject_ptr) == 0) {
        imp->handlers.insert(std::make_pair(&subject, typename impl::handler_holder{}));
    };
    imp->handlers.at(&subject).add_handler(key, handler);

    subject._impl->add_observer(*this, key);
}

template <typename T>
void observer<T>::remove_handler(subject<T> &subject, const std::string &key) {
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

template <typename T>
void observer<T>::add_wild_card_handler(subject<T> &subject, const handler_f &handler) {
    auto imp = impl_ptr<impl>();
    auto subject_ptr = &subject;
    if (imp->handlers.count(subject_ptr) == 0) {
        imp->handlers.insert(std::make_pair(&subject, typename impl::handler_holder{}));
    };
    imp->handlers.at(&subject).add_handler(nullopt, handler);
    subject._impl->add_observer(*this, nullopt);
}

template <typename T>
void observer<T>::remove_wild_card_handler(subject<T> &subject) {
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

template <typename T>
void observer<T>::clear() {
    auto id = identifier();
    auto imp = impl_ptr<impl>();
    for (auto &pair : imp->handlers) {
        auto &subject_ptr = pair.first;
        subject_ptr->_impl->remove_observer(id);
    }
    imp->handlers.clear();
}

#pragma mark - subject

template <typename T>
subject<T>::subject()
    : _impl(std::make_unique<impl>()) {
}

template <typename T>
subject<T>::~subject() {
    for (auto &pair : _impl->observers) {
        for (auto &weak_observer : pair.second) {
            if (auto obs = weak_observer.lock()) {
                obs.template impl_ptr<typename observer<T>::impl>()->handlers.erase(this);
            }
        }
    }
}

template <typename T>
bool subject<T>::operator==(const subject &rhs) const {
    return this == &rhs;
}

template <typename T>
bool subject<T>::operator!=(const subject &rhs) const {
    return this != &rhs;
}

template <typename T>
void subject<T>::notify(const std::string &key) const {
    notify(key, nullptr);
}

template <typename T>
void subject<T>::notify(const std::string &key, const T &object) const {
    if (_impl->observers.count(key)) {
        for (auto &weak_observer : _impl->observers.at(key)) {
            if (observer<T> obs = weak_observer.lock()) {
                obs.template impl_ptr<typename observer<T>::impl>()->call_handler(*this, key, object);
            }
        }
    }
    if (_impl->observers.count(nullopt)) {
        for (auto &weak_observer : _impl->observers.at(nullopt)) {
            if (auto obs = weak_observer.lock()) {
                obs.template impl_ptr<typename observer<T>::impl>()->call_wild_card_handler(*this, key, object);
            }
        }
    }
}

template <typename T>
observer<T> subject<T>::make_observer(const std::string &key, const typename observer<T>::handler_f &handler) {
    observer<T> obs;
    obs.add_handler(*this, key, handler);
    return obs;
}

template <typename T>
observer<T> subject<T>::make_wild_card_observer(const typename observer<T>::handler_f &handler) {
    observer<T> obs;
    obs.add_wild_card_handler(*this, handler);
    return obs;
}
}

template <typename T>
yas::observer<T> yas::make_subject_dispatcher(const subject<T> &source,
                                              const std::initializer_list<subject<T> *> &destinations) {
    observer<T> observer;
    auto handler = [&source](const auto &method, const auto &value) { source.notify(method, value); };

    for (const auto &destination : destinations) {
        observer.add_wild_card_handler(*destination, handler);
    }

    return observer;
}
