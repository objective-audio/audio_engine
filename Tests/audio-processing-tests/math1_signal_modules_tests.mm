//
//  math1_modules_tests.mm
//

#import <XCTest/XCTest.h>
#import "utils/test_utils.h"

using namespace yas;
using namespace yas::proc;

namespace yas {
namespace test {
    static double constexpr two_pi = 2.0 * M_PI;

    static std::size_t constexpr process_length = 8;

    static double constexpr radian_input_data[process_length] = {
        0.0, 0.25 * two_pi, 0.5 * two_pi, 0.75 * two_pi, 1.0 * two_pi, 1.25 * two_pi, 1.5 * two_pi, 1.75 * two_pi,
    };

    static double constexpr linear_input_data[process_length]{
        -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0,
    };
}  // namespace test
}  // namespace yas

@interface math1_signal_modules_tests : XCTestCase

@end

@implementation math1_signal_modules_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_signal_module {
    XCTAssertTrue(make_signal_module<double>(math1::kind::sin));
    XCTAssertTrue(make_signal_module<double>(math1::kind::cos));
    XCTAssertTrue(make_signal_module<double>(math1::kind::tan));
    XCTAssertTrue(make_signal_module<double>(math1::kind::asin));
    XCTAssertTrue(make_signal_module<double>(math1::kind::acos));
    XCTAssertTrue(make_signal_module<double>(math1::kind::atan));

    XCTAssertTrue(make_signal_module<double>(math1::kind::sinh));
    XCTAssertTrue(make_signal_module<double>(math1::kind::cosh));
    XCTAssertTrue(make_signal_module<double>(math1::kind::tanh));
    XCTAssertTrue(make_signal_module<double>(math1::kind::asinh));
    XCTAssertTrue(make_signal_module<double>(math1::kind::acosh));
    XCTAssertTrue(make_signal_module<double>(math1::kind::atanh));

    XCTAssertTrue(make_signal_module<double>(math1::kind::exp2));
    XCTAssertTrue(make_signal_module<double>(math1::kind::expm1));
    XCTAssertTrue(make_signal_module<double>(math1::kind::log));
    XCTAssertTrue(make_signal_module<double>(math1::kind::log10));
    XCTAssertTrue(make_signal_module<double>(math1::kind::log1p));
    XCTAssertTrue(make_signal_module<double>(math1::kind::log2));

    XCTAssertTrue(make_signal_module<double>(math1::kind::sqrt));
    XCTAssertTrue(make_signal_module<double>(math1::kind::cbrt));
    XCTAssertTrue(make_signal_module<double>(math1::kind::abs));

    XCTAssertTrue(make_signal_module<double>(math1::kind::ceil));
    XCTAssertTrue(make_signal_module<double>(math1::kind::floor));
    XCTAssertTrue(make_signal_module<double>(math1::kind::trunc));
    XCTAssertTrue(make_signal_module<double>(math1::kind::round));
}

- (void)test_sin {
    channel_index_t const ch_idx = 3;

    auto module = test::make_signal_module<double>(math1::kind::sin, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::radian_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::sin(test::radian_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::sin(test::radian_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::sin(test::radian_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::sin(test::radian_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::sin(test::radian_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::sin(test::radian_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::sin(test::radian_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::sin(test::radian_input_data[7]), 0.01);
}

- (void)test_cos {
    channel_index_t const ch_idx = 4;

    auto module = test::make_signal_module<double>(math1::kind::cos, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::radian_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::cos(test::radian_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::cos(test::radian_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::cos(test::radian_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::cos(test::radian_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::cos(test::radian_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::cos(test::radian_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::cos(test::radian_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::cos(test::radian_input_data[7]), 0.01);
}

- (void)test_tan {
    channel_index_t const ch_idx = 5;

    auto module = test::make_signal_module<double>(math1::kind::tan, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::radian_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::tan(test::radian_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::tan(test::radian_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::tan(test::radian_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::tan(test::radian_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::tan(test::radian_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::tan(test::radian_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::tan(test::radian_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::tan(test::radian_input_data[7]), 0.01);
}

- (void)test_asin {
    channel_index_t const ch_idx = 6;

    auto module = test::make_signal_module<double>(math1::kind::asin, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertEqualWithAccuracy(vec[1], std::asin(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::asin(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::asin(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::asin(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::asin(test::linear_input_data[5]), 0.01);
    XCTAssertTrue(std::isnan(vec[6]));
    XCTAssertTrue(std::isnan(vec[7]));
}

- (void)test_acos {
    channel_index_t const ch_idx = 7;

    auto module = test::make_signal_module<double>(math1::kind::acos, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertEqualWithAccuracy(vec[1], std::acos(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::acos(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::acos(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::acos(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::acos(test::linear_input_data[5]), 0.01);
    XCTAssertTrue(std::isnan(vec[6]));
    XCTAssertTrue(std::isnan(vec[7]));
}

- (void)test_atan {
    channel_index_t const ch_idx = 8;

    auto module = test::make_signal_module<double>(math1::kind::atan, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::atan(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::atan(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::atan(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::atan(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::atan(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::atan(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::atan(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::atan(test::linear_input_data[7]), 0.01);
}

- (void)test_sinh {
    channel_index_t const ch_idx = 40;

    auto module = test::make_signal_module<double>(math1::kind::sinh, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::sinh(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::sinh(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::sinh(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::sinh(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::sinh(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::sinh(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::sinh(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::sinh(test::linear_input_data[7]), 0.01);
}

- (void)test_cosh {
    channel_index_t const ch_idx = 41;

    auto module = test::make_signal_module<double>(math1::kind::cosh, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::cosh(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::cosh(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::cosh(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::cosh(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::cosh(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::cosh(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::cosh(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::cosh(test::linear_input_data[7]), 0.01);
}

- (void)test_tanh {
    channel_index_t const ch_idx = 42;

    auto module = test::make_signal_module<double>(math1::kind::tanh, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::tanh(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::tanh(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::tanh(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::tanh(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::tanh(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::tanh(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::tanh(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::tanh(test::linear_input_data[7]), 0.01);
}

- (void)test_asinh {
    channel_index_t const ch_idx = 43;

    auto module = test::make_signal_module<double>(math1::kind::asinh, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::asinh(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::asinh(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::asinh(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::asinh(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::asinh(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::asinh(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::asinh(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::asinh(test::linear_input_data[7]), 0.01);
}

- (void)test_acosh {
    channel_index_t const ch_idx = 44;

    auto module = test::make_signal_module<double>(math1::kind::acosh, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertTrue(std::isnan(vec[1]));
    XCTAssertTrue(std::isnan(vec[2]));
    XCTAssertTrue(std::isnan(vec[3]));
    XCTAssertTrue(std::isnan(vec[4]));
    XCTAssertEqualWithAccuracy(vec[5], std::acosh(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::acosh(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::acosh(test::linear_input_data[7]), 0.01);
}

- (void)test_atanh {
    channel_index_t const ch_idx = 45;

    auto module = test::make_signal_module<double>(math1::kind::atanh, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertEqualWithAccuracy(vec[1], std::atanh(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::atanh(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::atanh(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::atanh(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::atanh(test::linear_input_data[5]), 0.01);
    XCTAssertTrue(std::isnan(vec[6]));
    XCTAssertTrue(std::isnan(vec[7]));
}

- (void)test_exp {
    channel_index_t const ch_idx = 20;

    auto module = test::make_signal_module<double>(math1::kind::exp, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::exp(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::exp(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::exp(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::exp(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::exp(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::exp(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::exp(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::exp(test::linear_input_data[7]), 0.01);
}

- (void)test_exp2 {
    channel_index_t const ch_idx = 21;

    auto module = test::make_signal_module<double>(math1::kind::exp2, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::exp2(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::exp2(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::exp2(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::exp2(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::exp2(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::exp2(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::exp2(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::exp2(test::linear_input_data[7]), 0.01);
}

- (void)test_expm1 {
    channel_index_t const ch_idx = 22;

    auto module = test::make_signal_module<double>(math1::kind::expm1, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::expm1(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::expm1(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::expm1(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::expm1(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::expm1(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::expm1(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::expm1(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::expm1(test::linear_input_data[7]), 0.01);
}

- (void)test_log {
    channel_index_t const ch_idx = 23;

    auto module = test::make_signal_module<double>(math1::kind::log, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertTrue(std::isnan(vec[1]));
    XCTAssertTrue(std::isnan(vec[2]));
    XCTAssertEqualWithAccuracy(vec[3], std::log(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::log(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::log(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::log(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::log(test::linear_input_data[7]), 0.01);
}

- (void)test_log10 {
    channel_index_t const ch_idx = 24;

    auto module = test::make_signal_module<double>(math1::kind::log10, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertTrue(std::isnan(vec[1]));
    XCTAssertTrue(std::isnan(vec[2]));
    XCTAssertEqualWithAccuracy(vec[3], std::log10(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::log10(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::log10(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::log10(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::log10(test::linear_input_data[7]), 0.01);
}

- (void)test_log1p {
    channel_index_t const ch_idx = 25;

    auto module = test::make_signal_module<double>(math1::kind::log1p, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertEqualWithAccuracy(vec[1], std::log1p(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::log1p(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::log1p(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::log1p(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::log1p(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::log1p(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::log1p(test::linear_input_data[7]), 0.01);
}

- (void)test_log2 {
    channel_index_t const ch_idx = 26;

    auto module = test::make_signal_module<double>(math1::kind::log2, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertTrue(std::isnan(vec[1]));
    XCTAssertTrue(std::isnan(vec[2]));
    XCTAssertEqualWithAccuracy(vec[3], std::log2(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::log2(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::log2(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::log2(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::log2(test::linear_input_data[7]), 0.01);
}

- (void)test_sqrt {
    channel_index_t const ch_idx = 9;

    auto module = test::make_signal_module<double>(math1::kind::sqrt, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertTrue(std::isnan(vec[0]));
    XCTAssertTrue(std::isnan(vec[1]));
    XCTAssertTrue(std::isnan(vec[2]));
    XCTAssertEqualWithAccuracy(vec[3], std::sqrt(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::sqrt(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::sqrt(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::sqrt(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::sqrt(test::linear_input_data[7]), 0.01);
}

- (void)test_cbrt {
    channel_index_t const ch_idx = 10;

    auto module = test::make_signal_module<double>(math1::kind::cbrt, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::cbrt(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::cbrt(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::cbrt(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::cbrt(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::cbrt(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::cbrt(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::cbrt(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::cbrt(test::linear_input_data[7]), 0.01);
}

- (void)test_abs {
    channel_index_t const ch_idx = 11;

    auto module = test::make_signal_module<double>(math1::kind::abs, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], 1.5, 0.01);
    XCTAssertEqualWithAccuracy(vec[1], 1.0, 0.01);
    XCTAssertEqualWithAccuracy(vec[2], 0.5, 0.01);
    XCTAssertEqualWithAccuracy(vec[3], 0.0, 0.01);
    XCTAssertEqualWithAccuracy(vec[4], 0.5, 0.01);
    XCTAssertEqualWithAccuracy(vec[5], 1.0, 0.01);
    XCTAssertEqualWithAccuracy(vec[6], 1.5, 0.01);
    XCTAssertEqualWithAccuracy(vec[7], 2.0, 0.01);
}

- (void)test_ceil {
    channel_index_t const ch_idx = 30;

    auto module = test::make_signal_module<double>(math1::kind::ceil, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::ceil(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::ceil(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::ceil(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::ceil(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::ceil(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::ceil(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::ceil(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::ceil(test::linear_input_data[7]), 0.01);
}

- (void)test_floor {
    channel_index_t const ch_idx = 31;

    auto module = test::make_signal_module<double>(math1::kind::floor, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::floor(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::floor(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::floor(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::floor(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::floor(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::floor(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::floor(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::floor(test::linear_input_data[7]), 0.01);
}

- (void)test_trunc {
    channel_index_t const ch_idx = 32;

    auto module = test::make_signal_module<double>(math1::kind::trunc, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::trunc(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::trunc(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::trunc(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::trunc(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::trunc(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::trunc(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::trunc(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::trunc(test::linear_input_data[7]), 0.01);
}

- (void)test_round {
    channel_index_t const ch_idx = 33;

    auto module = test::make_signal_module<double>(math1::kind::round, ch_idx);
    auto stream = test::make_signal_stream<double>(time::range{0, test::process_length}, test::linear_input_data,
                                                   time::range{0, test::process_length}, ch_idx);

    module->process(time::range{0, test::process_length}, stream);

    auto const &events = stream.channel(ch_idx).events();
    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqualWithAccuracy(vec[0], std::round(test::linear_input_data[0]), 0.01);
    XCTAssertEqualWithAccuracy(vec[1], std::round(test::linear_input_data[1]), 0.01);
    XCTAssertEqualWithAccuracy(vec[2], std::round(test::linear_input_data[2]), 0.01);
    XCTAssertEqualWithAccuracy(vec[3], std::round(test::linear_input_data[3]), 0.01);
    XCTAssertEqualWithAccuracy(vec[4], std::round(test::linear_input_data[4]), 0.01);
    XCTAssertEqualWithAccuracy(vec[5], std::round(test::linear_input_data[5]), 0.01);
    XCTAssertEqualWithAccuracy(vec[6], std::round(test::linear_input_data[6]), 0.01);
    XCTAssertEqualWithAccuracy(vec[7], std::round(test::linear_input_data[7]), 0.01);
}

@end
