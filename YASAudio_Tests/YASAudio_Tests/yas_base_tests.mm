//
//  yas_base_tests.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

namespace yas {
namespace test {
    class test_derived : public base {
        using super_class = base;

       public:
        class impl : public base::impl {
           public:
            float value;
        };

        test_derived() : super_class(std::make_shared<impl>()) {
        }

        test_derived(std::nullptr_t) : super_class(nullptr) {
        }

        void set_value(float val) {
            impl_ptr<impl>()->value = val;
        }

        float value() const {
            return impl_ptr<impl>()->value;
        }

        template <typename T>
        T object_from_impl() {
            return impl_ptr()->cast<T>();
        }
    };

    class test_derived2 : public base {
        using super_class = base;

       public:
        class impl : public base::impl {
           public:
            float value;
        };

        test_derived2(std::nullptr_t) : super_class(nullptr) {
        }
    };
}
}

@interface yas_base_tests : XCTestCase

@end

@implementation yas_base_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_lock_values {
    yas::test::test_derived derived_1;
    yas::test::test_derived derived_2;

    derived_1.set_value(1.0f);
    derived_2.set_value(2.0f);

    auto weak_1 = yas::to_weak(derived_1);
    auto weak_2 = yas::to_weak(derived_2);

    std::map<int, decltype(weak_1)> map;
    map.insert(std::make_pair(1, weak_1));
    map.insert(std::make_pair(2, weak_2));

    auto locked_map = yas::lock_values(map);

    for (auto &pair : locked_map) {
        switch (pair.first) {
            case 1:
                XCTAssertEqual(pair.second.value(), 1.0f);
                break;
            case 2:
                XCTAssertEqual(pair.second.value(), 2.0f);
                break;
            default:
                break;
        }
    }
}

- (void)test_cast_success {
    yas::test::test_derived derived;
    yas::base base = derived;

    auto casted = base.cast<yas::test::test_derived>();

    XCTAssertTrue(!!casted);
}

- (void)test_cast_failed {
    yas::base base{nullptr};
    base.set_impl_ptr(std::make_shared<yas::base::impl>());

    auto casted = base.cast<yas::test::test_derived>();

    XCTAssertFalse(!!casted);
}

- (void)test_make_object_from_impl_success {
    yas::test::test_derived derived;

    auto derived_from_impl = derived.object_from_impl<yas::test::test_derived>();

    XCTAssertTrue(!!derived_from_impl);
}

- (void)test_make_object_from_impl_failed {
    yas::test::test_derived derived;

    auto derived2_from_impl = derived.object_from_impl<yas::test::test_derived2>();

    XCTAssertFalse(!!derived2_from_impl);
}

- (void)test_equal_to_nullptr {
    yas::base base{nullptr};

    XCTAssertTrue(base == nullptr);

    base.set_impl_ptr(std::make_shared<yas::base::impl>());

    XCTAssertFalse(base == nullptr);
}

- (void)test_not_equal_to_nullptr {
    yas::base base{nullptr};

    XCTAssertFalse(base != nullptr);

    base.set_impl_ptr(std::make_shared<yas::base::impl>());

    XCTAssertTrue(base != nullptr);
}

- (void)test_derived_equal_to_nullptr {
    yas::test::test_derived derived{nullptr};

    XCTAssertTrue(derived == nullptr);

    derived.set_impl_ptr(std::make_shared<yas::test::test_derived::impl>());

    XCTAssertFalse(derived == nullptr);
}

- (void)test_expired {
    yas::base base{nullptr};

    XCTAssertTrue(base.expired());

    base.set_impl_ptr(std::make_shared<yas::base::impl>());

    XCTAssertFalse(base.expired());

    base.set_impl_ptr(nullptr);

    XCTAssertTrue(base.expired());
}

- (void)test_compare {
    yas::base base1{nullptr};
    yas::base base2{nullptr};

    XCTAssertFalse(base1 < base2);
    XCTAssertFalse(base2 < base1);

    auto impl1 = std::make_shared<yas::base::impl>();
    auto impl2 = std::make_shared<yas::base::impl>();

    base1.set_impl_ptr(impl1);
    base2.set_impl_ptr(impl2);

    bool compare_impl = impl1 < impl2;
    bool compare_base = base1 < base2;

    XCTAssertEqual(compare_impl, compare_base);
}

@end
