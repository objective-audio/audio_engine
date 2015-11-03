//
//  yas_base_tests.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

namespace yas
{
    namespace test
    {
        class test_derived : public base
        {
            using super_class = base;

            class impl : public base::impl
            {
               public:
                float value;
            };

           public:
            test_derived() : super_class(std::make_shared<impl>())
            {
            }

            test_derived(std::nullptr_t) : super_class(nullptr)
            {
            }

            void set_value(float val)
            {
                impl_ptr<impl>()->value = val;
            }

            float value() const
            {
                return impl_ptr<impl>()->value;
            }
        };
    }
}

@interface yas_base_tests : XCTestCase

@end

@implementation yas_base_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_lock_values
{
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

@end
