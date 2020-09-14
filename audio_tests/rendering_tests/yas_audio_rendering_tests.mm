//
//  yas_audio_rendering_tests.mm
//

#import <XCTest/XCTest.h>
#include <audio/yas_audio_rendering_graph.h>

using namespace yas;

@interface yas_audio_rendering_tests : XCTestCase

@end

@implementation yas_audio_rendering_tests

- (void)test_rendering_node {
    enum called_node {
        input_0,
        input_1,
        output,
    };

    struct called_context {
        called_node node;
        uint32_t bus_idx;
    };

    audio::format format{{.sample_rate = 4, .channel_count = 1}};

    std::vector<called_context> called;

    audio::rendering_node const input_node_0{
        [&called](audio::rendering_node::render_args const &args) {
            called.emplace_back(called_context{.node = called_node::input_0, .bus_idx = args.bus_idx});

            if (args.bus_idx == 0) {
                args.buffer->data_ptr_at_index<float>(0)[0] = 0.1f;
            }
        },
        {}};
    audio::rendering_node const input_node_1{
        [&called](audio::rendering_node::render_args const &args) {
            called.emplace_back(called_context{.node = called_node::input_1, .bus_idx = args.bus_idx});

            if (args.bus_idx == 1) {
                args.buffer->data_ptr_at_index<float>(0)[1] = 0.2f;
            } else if (args.bus_idx == 2) {
                args.buffer->data_ptr_at_index<float>(0)[2] = 0.3f;
            }
        },
        {}};

    audio::rendering_node const output_node{
        [&called](audio::rendering_node::render_args const &args) {
            called.emplace_back(called_context{.node = called_node::output, .bus_idx = args.bus_idx});

            if (args.bus_idx == 0) {
                args.buffer->data_ptr_at_index<float>(0)[3] = 0.4f;
            }

            for (auto [bus_idx, connection] : args.source_connections) {
                connection.render(args.buffer, args.time);
            }
        },
        {{0, {.source_bus_idx = 0, .source_node = &input_node_0, .format = format}},
         {1, {.source_bus_idx = 1, .source_node = &input_node_1, .format = format}},
         {2, {.source_bus_idx = 2, .source_node = &input_node_1, .format = format}}}};

    XCTAssertEqual(called.size(), 0);

    audio::pcm_buffer buffer{format, 4};
    audio::time time{0};

    output_node.render_handler()(
        {.buffer = &buffer, .bus_idx = 0, .time = time, .source_connections = output_node.source_connections()});

    XCTAssertEqual(called.size(), 4);
    XCTAssertEqual(called.at(0).node, called_node::output);
    XCTAssertEqual(called.at(0).bus_idx, 0);
    XCTAssertEqual(called.at(1).node, called_node::input_0);
    XCTAssertEqual(called.at(1).bus_idx, 0);
    XCTAssertEqual(called.at(2).node, called_node::input_1);
    XCTAssertEqual(called.at(2).bus_idx, 1);
    XCTAssertEqual(called.at(3).node, called_node::input_1);
    XCTAssertEqual(called.at(3).bus_idx, 2);

    auto const *data = buffer.data_ptr_at_index<float>(0);
    XCTAssertEqual(data[0], 0.1f);
    XCTAssertEqual(data[1], 0.2f);
    XCTAssertEqual(data[2], 0.3f);
    XCTAssertEqual(data[3], 0.4f);
}

- (void)test_rendering_graph {
}

@end
