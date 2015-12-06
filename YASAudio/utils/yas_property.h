//
//  yas_property.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_observing.h"
#include "yas_base.h"
#include <memory>
#include <mutex>

namespace yas {
namespace property_method {
    static const auto will_change = "yas.property.will_change";
    static const auto did_change = "yas.property.did_change";
};

struct null_key {};

template <typename T, typename K = null_key>
class property : public base {
    using super_class = base;

   public:
    property();
    explicit property(const K &key);
    property(const K &key, const T &value);
    property(std::nullptr_t);

    bool operator==(const property &) const;
    bool operator!=(const property &) const;
    bool operator==(const T &) const;
    bool operator!=(const T &) const;

    const K &key() const;
    void set_value(const T &value);
    const T &value() const;

    subject<property> &subject();

   private:
    class impl;
};
}

#include "yas_property_private.h"
