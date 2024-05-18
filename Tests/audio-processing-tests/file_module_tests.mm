//
//  file_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/maker/file_module.h>
#import <audio-engine/umbrella.hpp>
#import "utils/test_utils.h"

using namespace yas;
using namespace yas::proc;

namespace yas::proc::test_utils::file_module {
static double constexpr sample_rate = 48000;
static uint32_t constexpr ch_count = 2;
static uint32_t constexpr bit_depth = 16;
static audio::pcm_format constexpr pcm_format = audio::pcm_format::int16;

static void setup_file(std::filesystem::path const &path) {
    auto const file_result =
        audio::file::make_created({.file_path = path,
                                   .pcm_format = pcm_format,
                                   .settings = audio::wave_file_settings(sample_rate, ch_count, bit_depth)});
    XCTAssertTrue(file_result.is_success());
    auto const &file = file_result.value();

    auto buffer = audio::pcm_buffer(file->processing_format(), 2);
    auto *data0 = buffer.data_ptr_at_index<int16_t>(0);
    data0[0] = 10;
    data0[1] = 11;
    auto *data1 = buffer.data_ptr_at_index<int16_t>(1);
    data1[0] = 20;
    data1[1] = 21;

    file->write_from_buffer(buffer);

    file->close();
}
}  // namespace yas::proc::test_utils::file_module

@interface file_module_tests : XCTestCase

@end

@implementation file_module_tests

- (void)setUp {
    [super setUp];
    test_utils::remove_contents_in_test_directory();
    test_utils::create_test_directory();
}

- (void)tearDown {
    test_utils::remove_contents_in_test_directory();
    [super tearDown];
}

- (void)test_context_read_from_file {
    auto path = test_utils::test_path().append("test.wav");
    test_utils::file_module::setup_file(path);

    file::context<int16_t> const context{path, 0, 0};

    audio::format const format{{.sample_rate = test_utils::file_module::sample_rate,
                                .channel_count = 1,
                                .pcm_format = test_utils::file_module::pcm_format}};
    audio::pcm_buffer buffer{format, 2};
    auto data = buffer.data_ptr_at_index<int16_t>(0);

    sync_source const sync_src{(sample_rate_t)test_utils::file_module::sample_rate, 2};

    [XCTContext runActivityNamed:@"範囲内のchannel0"
                           block:^(id<XCTActivity> activity) {
                               context.read_from_file(time::range{-2, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{-1, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 10);

                               context.read_from_file(time::range{0, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 10);
                               XCTAssertEqual(data[1], 11);

                               context.read_from_file(time::range{1, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 11);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{2, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);
                           }];

    [XCTContext runActivityNamed:@"範囲内のchannel1"
                           block:^(id<XCTActivity> activity) {
                               context.read_from_file(time::range{-2, 2}, sync_src, 1, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{-1, 2}, sync_src, 1, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 20);

                               context.read_from_file(time::range{0, 2}, sync_src, 1, data);

                               XCTAssertEqual(data[0], 20);
                               XCTAssertEqual(data[1], 21);

                               context.read_from_file(time::range{1, 2}, sync_src, 1, data);

                               XCTAssertEqual(data[0], 21);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{2, 2}, sync_src, 1, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);
                           }];

    [XCTContext runActivityNamed:@"範囲外のchannelなので0が返る"
                           block:^(id<XCTActivity> activity) {
                               context.read_from_file(time::range{0, 2}, sync_src, 2, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);
                           }];

    [XCTContext runActivityNamed:@"型が違うが変換される"
                           block:^(id<XCTActivity> activity) {
                               file::context<float> const context{path, 0, 0};

                               audio::format const format{{.sample_rate = test_utils::file_module::sample_rate,
                                                           .channel_count = 1,
                                                           .pcm_format = audio::pcm_format::float32}};
                               audio::pcm_buffer buffer{format, 2};
                               auto data = buffer.data_ptr_at_index<float>(0);

                               context.read_from_file(time::range{0, 2}, sync_src, 0, data);

                               XCTAssertEqual(int16_t(round(data[0] * INT16_MAX)), 10);
                               XCTAssertEqual(int16_t(round(data[1] * INT16_MAX)), 11);
                           }];

    [XCTContext
        runActivityNamed:@"sample_rateが違うので0が返る"
                   block:^(id<XCTActivity> activity) {
                       file::context<float> const context{path, 0, 0};

                       audio::format const format{
                           {.sample_rate = 96000, .channel_count = 1, .pcm_format = audio::pcm_format::float32}};
                       audio::pcm_buffer buffer{format, 2};
                       auto data = buffer.data_ptr_at_index<float>(0);

                       context.read_from_file(time::range{0, 2}, sync_source{96000, 2}, 0, data);

                       XCTAssertEqual(data[0], 0);
                       XCTAssertEqual(data[1], 0);
                   }];

    [XCTContext runActivityNamed:@"module_offsetをずらす"
                           block:^(id<XCTActivity> activity) {
                               file::context<int16_t> const context{path, 10, 0};

                               context.read_from_file(time::range{8, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{9, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 10);

                               context.read_from_file(time::range{10, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 10);
                               XCTAssertEqual(data[1], 11);

                               context.read_from_file(time::range{11, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 11);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{12, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);
                           }];

    [XCTContext runActivityNamed:@"file_offsetをずらす"
                           block:^(id<XCTActivity> activity) {
                               file::context<int16_t> const context{path, 0, 1};

                               context.read_from_file(time::range{-2, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{-1, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 11);

                               context.read_from_file(time::range{0, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 11);
                               XCTAssertEqual(data[1], 0);

                               context.read_from_file(time::range{1, 2}, sync_src, 0, data);

                               XCTAssertEqual(data[0], 0);
                               XCTAssertEqual(data[1], 0);
                           }];
}

- (void)test_make_signal_module {
    auto const path = test_utils::test_path().append("test.wav");

    XCTAssertTrue(file::make_signal_module<double>(path, 0, 0));
    XCTAssertTrue(file::make_signal_module<float>(path, 0, 0));
    XCTAssertTrue(file::make_signal_module<int32_t>(path, 0, 0));
    XCTAssertTrue(file::make_signal_module<int16_t>(path, 0, 0));
}

- (void)test_process {
    length_t const process_length = 4;

    auto const path = test_utils::test_path().append("test.wav");
    test_utils::file_module::setup_file(path);

    sync_source const sync_src{(sample_rate_t)test_utils::file_module::sample_rate, process_length};

    auto const module = file::make_signal_module<int16_t>(path, 0, 0);

    module->connect_output(0, 0);
    module->connect_output(1, 1);
    module->connect_output(2, 2);

    stream stream{sync_src};
    time::range const time_range{-1, process_length};

    module->process(time_range, stream);

    {
        auto const &channel = stream.channel(0);
        auto const events = channel.filtered_events<int16_t, signal_event>();
        XCTAssertEqual(events.size(), 1);

        auto const &pair = *events.cbegin();
        XCTAssertEqual(pair.first, time_range);
        auto const *data = pair.second->data<int16_t>();
        XCTAssertEqual(data[0], 0);
        XCTAssertEqual(data[1], 10);
        XCTAssertEqual(data[2], 11);
        XCTAssertEqual(data[3], 0);
    }

    {
        auto const &channel = stream.channel(1);
        auto const events = channel.filtered_events<int16_t, signal_event>();
        XCTAssertEqual(events.size(), 1);

        auto const &pair = *events.cbegin();
        XCTAssertEqual(pair.first, time_range);
        auto const *data = pair.second->data<int16_t>();
        XCTAssertEqual(data[0], 0);
        XCTAssertEqual(data[1], 20);
        XCTAssertEqual(data[2], 21);
        XCTAssertEqual(data[3], 0);
    }

    {
        auto const &channel = stream.channel(2);
        auto const events = channel.filtered_events<int16_t, signal_event>();
        XCTAssertEqual(events.size(), 1);

        auto const &pair = *events.cbegin();
        XCTAssertEqual(pair.first, time_range);
        auto const *data = pair.second->data<int16_t>();
        XCTAssertEqual(data[0], 0);
        XCTAssertEqual(data[1], 0);
        XCTAssertEqual(data[2], 0);
        XCTAssertEqual(data[3], 0);
    }
}

@end
