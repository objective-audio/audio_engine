//
//  yas_audio_rendering_tests.mm
//

#import <XCTest/XCTest.h>
#include <audio/yas_audio_rendering_graph.h>

using namespace yas;

@interface yas_audio_rendering_tests : XCTestCase

@end

@implementation yas_audio_rendering_tests

- (void)test_render {
    enum called_node {
        input_0,
        input_1,
        output,
    };

    std::vector<std::pair<called_node, uint32_t>> called;

    audio::rendering_node const input_node_0{
        .render_handler = [&called](auto const &args) { called.emplace_back(called_node::input_0, args.bus_idx); },
        .source_connections = {}};
    audio::rendering_node const input_node_1{
        .render_handler = [&called](auto const &args) { called.emplace_back(called_node::input_1, args.bus_idx); },
        .source_connections = {}};

    audio::rendering_node const output_node{
        .render_handler =
            [&called](audio::rendering_node::render_args const &args) {
                called.emplace_back(called_node::output, args.bus_idx);
                for (auto [bus_idx, connection] : args.source_connections) {
                    connection.render(args.buffer, args.time);
                }
            },
        .source_connections = {{0, {.source_bus_idx = 0, .source_node = &input_node_0}},
                               {1, {.source_bus_idx = 1, .source_node = &input_node_1}},
                               {2, {.source_bus_idx = 2, .source_node = &input_node_1}}}};

    XCTAssertEqual(called.size(), 0);

    audio::format format{{.sample_rate = 2, .channel_count = 1}};
    audio::pcm_buffer buffer{format, 2};
    audio::time time{0};

    output_node.render_handler(
        {.buffer = &buffer, .bus_idx = 0, .time = time, .source_connections = output_node.source_connections});

    XCTAssertEqual(called.size(), 4);
    XCTAssertEqual(called.at(0).first, called_node::output);
    XCTAssertEqual(called.at(1).first, called_node::input_0);
    XCTAssertEqual(called.at(2).first, called_node::input_1);
    XCTAssertEqual(called.at(3).first, called_node::input_1);
}

@end
