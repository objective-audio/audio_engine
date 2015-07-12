//
//  yas_objc_container.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <Foundation/Foundation.h>
#include <mutex>
#include <memory>

namespace yas
{
    class objc_container;
    using objc_container_ptr = std::shared_ptr<objc_container>;

    class objc_container
    {
       public:
        static objc_container_ptr create();
        static objc_container_ptr create(const id object);

        objc_container();
        explicit objc_container(const id object);
        ~objc_container();

        void set_object(const id object);
        id retained_object() const;
        id autoreleased_object() const;

       private:
        __unsafe_unretained id _objc_object;
        mutable std::recursive_mutex _mutex;
    };
}
