//
//  yas_pcm_buffer_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#include "yas_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_audio_channel_route.h"
#include "yas_audio_test_utils.h"
#include <memory>

@interface yas_pcm_buffer_tests : XCTestCase

@end

@implementation yas_pcm_buffer_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCreateStandardBuffer
{
    auto format = yas::audio_format::create(48000.0, 2);
    auto pcm_buffer = yas::pcm_buffer::create(format, 4);

    XCTAssertTrue(*format == *pcm_buffer->format());
    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssert(pcm_buffer->audio_ptr_at_index(1).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(2));
}

- (void)testCreateFloat32Interleaved1chBuffer
{
    auto pcm_buffer = yas::pcm_buffer::create(yas::audio_format::create(48000.0, 1, yas::pcm_format::float32, true), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(1));
}

- (void)testCreateFloat64NonInterleaved2chBuffer
{
    auto pcm_buffer =
        yas::pcm_buffer::create(yas::audio_format::create(48000.0, 2, yas::pcm_format::float64, false), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(2));
}

- (void)testCreateInt32Interleaved3chBuffer
{
    auto pcm_buffer =
        yas::pcm_buffer::create(yas::audio_format::create(48000.0, 3, yas::pcm_format::fixed824, true), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(3));
}

- (void)testCreateInt16NonInterleaved4chBuffer
{
    auto pcm_buffer = yas::pcm_buffer::create(yas::audio_format::create(48000.0, 4, yas::pcm_format::int16, false), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(4));
}

- (void)testSetFrameLength
{
    const UInt32 frame_capacity = 4;

    auto pcm_buffer = yas::pcm_buffer::create(yas::audio_format::create(48000.0, 1), frame_capacity);
    const auto &format = pcm_buffer->format();

    XCTAssertEqual(pcm_buffer->frame_length(), frame_capacity);
    XCTAssertEqual(pcm_buffer->audio_buffer_list()->mBuffers[0].mDataByteSize,
                   frame_capacity * format->buffer_frame_byte_count());

    pcm_buffer->set_frame_length(2);

    XCTAssertEqual(pcm_buffer->frame_length(), 2);
    XCTAssertEqual(pcm_buffer->audio_buffer_list()->mBuffers[0].mDataByteSize, 2 * format->buffer_frame_byte_count());

    pcm_buffer->set_frame_length(0);

    XCTAssertEqual(pcm_buffer->frame_length(), 0);
    XCTAssertEqual(pcm_buffer->audio_buffer_list()->mBuffers[0].mDataByteSize, 0);

    XCTAssertThrows(pcm_buffer->set_frame_length(5));
    XCTAssertEqual(pcm_buffer->frame_length(), 0);
}

- (void)testClearDataNonInterleaved
{
    const UInt32 frame_length = 4;

    auto format = yas::audio_format::create(48000.0, 2, yas::pcm_format::float32, false);
    auto buffer = yas::pcm_buffer::create(format, frame_length);

    [self _testClearBuffer:buffer];
}

- (void)testClearDataInterleaved
{
    const UInt32 frame_length = 4;

    auto format = yas::audio_format::create(48000, 2, yas::pcm_format::float32, true);
    auto buffer = yas::pcm_buffer::create(format, frame_length);

    [self _testClearBuffer:buffer];
}

- (void)_testClearBuffer:(yas::pcm_buffer_ptr &)buffer
{
    yas::test::fill_test_values_to_buffer(buffer);

    XCTAssertTrue(yas::test::is_filled_buffer(buffer));

    buffer->clear();

    XCTAssertTrue(yas::test::is_cleard_buffer(buffer));

    yas::test::fill_test_values_to_buffer(buffer);

    buffer->clear(1, 2);

    const UInt32 buffer_count = buffer->format()->buffer_count();
    const UInt32 stride = buffer->format()->stride();

    for (UInt32 buffer_index = 0; buffer_index < buffer_count; buffer_index++) {
        Float32 *ptr = buffer->audio_ptr_at_index<Float32>(buffer_index);
        for (UInt32 frame = 0; frame < buffer->frame_length(); frame++) {
            for (UInt32 ch = 0; ch < stride; ch++) {
                if (frame == 1 || frame == 2) {
                    XCTAssertEqual(ptr[frame * stride + ch], 0);
                } else {
                    XCTAssertNotEqual(ptr[frame * stride + ch], 0);
                }
            }
        }
    }
}

- (void)testCopyDataInterleavedFormatSuccess
{
    [self _testCopyDataFormatSuccessWithInterleaved:NO];
    [self _testCopyDataFormatSuccessWithInterleaved:YES];
}

- (void)_testCopyDataFormatSuccessWithInterleaved:(bool)interleaved
{
    const UInt32 frame_length = 4;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        const auto pcm_format = static_cast<yas::pcm_format>(i);
        auto format = yas::audio_format::create(48000.0, 2, pcm_format, interleaved);

        auto from_buffer = yas::pcm_buffer::create(format, frame_length);
        auto to_buffer = yas::pcm_buffer::create(format, frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        XCTAssertTrue(to_buffer->copy_from(from_buffer));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)testCopyDataDifferentInterleavedFormatSuccess
{
    const Float64 sample_rate = 48000;
    const UInt32 frame_length = 4;
    const UInt32 channels = 3;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        const auto pcm_format = static_cast<yas::pcm_format>(i);
        auto from_format = yas::audio_format::create(sample_rate, channels, pcm_format, true);
        auto to_format = yas::audio_format::create(sample_rate, channels, pcm_format, false);
        auto from_buffer = yas::pcm_buffer::create(from_format, frame_length);
        auto to_buffer = yas::pcm_buffer::create(to_format, frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        XCTAssertTrue(to_buffer->copy_from(from_buffer));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)testCopyDataDifferentFrameLength
{
    const Float64 sample_rate = 48000;
    const UInt32 channels = 1;
    const UInt32 from_frame_length = 4;
    const UInt32 to_frame_length = 2;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        const auto pcm_format = static_cast<yas::pcm_format>(i);
        auto format = yas::audio_format::create(sample_rate, channels, pcm_format, true);
        auto from_buffer = yas::pcm_buffer::create(format, from_frame_length);
        auto to_buffer = yas::pcm_buffer::create(format, to_frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        XCTAssertFalse(to_buffer->copy_from(from_buffer, 0, 0, from_frame_length));
        XCTAssertTrue(to_buffer->copy_from(from_buffer, 0, 0, to_frame_length));
        XCTAssertFalse(yas::test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)testCopyDataStartFrame
{
    [self _testCopyDataStartFrameWithInterleaved:YES];
    [self _testCopyDataStartFrameWithInterleaved:NO];
}

- (void)_testCopyDataStartFrameWithInterleaved:(BOOL)interleaved
{
    const Float64 sample_rate = 48000;
    const UInt32 from_frame_length = 4;
    const UInt32 to_frame_length = 8;
    const UInt32 from_start_frame = 2;
    const UInt32 to_start_frame = 4;
    const UInt32 channels = 2;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        const auto pcm_format = static_cast<yas::pcm_format>(i);
        auto format = yas::audio_format::create(sample_rate, channels, pcm_format, interleaved);

        auto from_buffer = yas::pcm_buffer::create(format, from_frame_length);
        auto to_buffer = yas::pcm_buffer::create(format, to_frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        const UInt32 length = 2;
        XCTAssertTrue(to_buffer->copy_from(from_buffer, from_start_frame, to_start_frame, length));

        for (UInt32 ch = 0; ch < channels; ch++) {
            for (UInt32 i = 0; i < length; i++) {
                auto from_ptr = yas::test::data_ptr_from_buffer(from_buffer, ch, from_start_frame + i);
                auto to_ptr = yas::test::data_ptr_from_buffer(to_buffer, ch, to_start_frame + i);
                XCTAssertEqual(memcmp(from_ptr.v, to_ptr.v, format->sample_byte_count()), 0);
                BOOL is_from_not_zero = NO;
                BOOL is_to_not_zero = NO;
                for (UInt32 j = 0; j < format->sample_byte_count(); j++) {
                    if (from_ptr.u8[j] != 0) {
                        is_from_not_zero = YES;
                    }
                    if (to_ptr.u8[j] != 0) {
                        is_to_not_zero = YES;
                    }
                }
                XCTAssertTrue(is_from_not_zero);
                XCTAssertTrue(is_to_not_zero);
            }
        }
    }
}

- (void)testCopyDataFlexiblySameFormat
{
    [self _testCopyDataFormatSuccessWithInterleaved:NO];
    [self _testCopyDataFormatSuccessWithInterleaved:YES];
}

- (void)_testCopyDataFlexiblySameFormatWithInterleaved:(BOOL)interleaved
{
    const Float64 sample_rate = 48000.0;
    const UInt32 frame_length = 4;
    const UInt32 channels = 2;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        const auto pcm_format = static_cast<yas::pcm_format>(i);
        auto format = yas::audio_format::create(sample_rate, channels, pcm_format, interleaved);

        auto from_buffer = yas::pcm_buffer::create(format, frame_length);
        auto to_buffer = yas::pcm_buffer::create(format, frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        XCTAssertNoThrow(to_buffer->copy_from(from_buffer));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(from_buffer, to_buffer));
    }
}

- (void)testCopyDataFlexiblyDifferentFormatSuccess
{
    [self _testCopyDataFlexiblyDifferentFormatSuccessFromInterleaved:NO];
    [self _testCopyDataFlexiblyDifferentFormatSuccessFromInterleaved:YES];
}

- (void)_testCopyDataFlexiblyDifferentFormatSuccessFromInterleaved:(BOOL)interleaved
{
    const Float64 sample_rate = 48000.0;
    const UInt32 frame_length = 4;
    const UInt32 channels = 2;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        auto pcm_format = static_cast<yas::pcm_format>(i);
        auto from_format = yas::audio_format::create(sample_rate, channels, pcm_format, interleaved);
        auto to_format = yas::audio_format::create(sample_rate, channels, pcm_format, !interleaved);

        auto to_buffer = yas::pcm_buffer::create(from_format, frame_length);
        auto from_buffer = yas::pcm_buffer::create(to_format, frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        XCTAssertNoThrow(to_buffer->copy_from(from_buffer));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(from_buffer, to_buffer));
        XCTAssertEqual(to_buffer->frame_length(), frame_length);
    }
}

- (void)testCopyDataFlexiblyDifferentPCMFormatFailed
{
    const Float64 sample_rate = 48000.0;
    const UInt32 frame_length = 4;
    const UInt32 channels = 2;
    const auto from_pcm_format = yas::pcm_format::float32;
    const auto to_pcm_format = yas::pcm_format::fixed824;

    auto from_format = yas::audio_format::create(sample_rate, channels, from_pcm_format, false);
    auto to_format = yas::audio_format::create(sample_rate, channels, to_pcm_format, true);

    auto from_buffer = yas::pcm_buffer::create(from_format, frame_length);
    auto to_buffer = yas::pcm_buffer::create(to_format, frame_length);

    XCTAssertFalse(to_buffer->copy_from(from_buffer));
}

- (void)testCopyDataFlexiblyFromAudioBufferListSameFormat
{
    const Float64 sample_rate = 48000.0;
    const UInt32 frame_length = 4;
    const UInt32 channels = 2;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        auto pcm_format = static_cast<yas::pcm_format>(i);
        auto interleaved_format = yas::audio_format::create(sample_rate, channels, pcm_format, true);
        auto non_interleaved_format = yas::audio_format::create(sample_rate, channels, pcm_format, false);
        auto interleaved_buffer = yas::pcm_buffer::create(interleaved_format, frame_length);
        auto deinterleaved_buffer = yas::pcm_buffer::create(non_interleaved_format, frame_length);

        yas::test::fill_test_values_to_buffer(interleaved_buffer);

        XCTAssertNoThrow(deinterleaved_buffer->copy_from(interleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
        XCTAssertEqual(deinterleaved_buffer->frame_length(), frame_length);

        interleaved_buffer->clear();
        deinterleaved_buffer->clear();

        yas::test::fill_test_values_to_buffer(deinterleaved_buffer);

        XCTAssertNoThrow(interleaved_buffer->copy_from(deinterleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
        XCTAssertEqual(interleaved_buffer->frame_length(), frame_length);
    }
}

- (void)testCopyDataFlexiblyToAudioBufferList
{
    const Float64 sample_rate = 48000.0;
    const UInt32 frame_length = 4;
    const UInt32 channels = 2;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        auto pcm_format = static_cast<yas::pcm_format>(i);
        auto interleaved_format = yas::audio_format::create(sample_rate, channels, pcm_format, true);
        auto non_interleaved_format = yas::audio_format::create(sample_rate, channels, pcm_format, false);
        auto interleaved_buffer = yas::pcm_buffer::create(interleaved_format, frame_length);
        auto deinterleaved_buffer = yas::pcm_buffer::create(non_interleaved_format, frame_length);

        yas::test::fill_test_values_to_buffer(interleaved_buffer);

        XCTAssertNoThrow(interleaved_buffer->copy_to(deinterleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));

        interleaved_buffer->clear();
        deinterleaved_buffer->clear();

        yas::test::fill_test_values_to_buffer(deinterleaved_buffer);

        XCTAssertNoThrow(deinterleaved_buffer->copy_to(interleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
    }
}

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)

- (void)testInitWithOutputChannelRoutes
{
    const UInt32 frame_length = 4;
    const UInt32 source_channels = 2;
    const UInt32 dest_channels = 4;
    const UInt32 bus = 0;
    const UInt32 sample_rate = 48000;
    const UInt32 dest_channel_indices[2] = {3, 0};

    auto dest_format = yas::audio_format::create(sample_rate, dest_channels);
    auto dest_buffer = yas::pcm_buffer::create(dest_format, frame_length);
    yas::test::fill_test_values_to_buffer(dest_buffer);

    auto channel_routes = std::vector<yas::channel_route_ptr>();
    for (UInt32 i = 0; i < source_channels; i++) {
        channel_routes.push_back(yas::channel_route::create(bus, i, bus, dest_channel_indices[i]));
    }

    auto source_format = yas::audio_format::create(sample_rate, source_channels);
    auto source_buffer = yas::pcm_buffer::create(source_format, *dest_buffer, channel_routes, true);

    for (UInt32 ch = 0; ch < source_channels; ++ch) {
        auto dest_ptr = dest_buffer->audio_ptr_at_index(dest_channel_indices[ch]);
        auto source_ptr = source_buffer->audio_ptr_at_index(ch);
        XCTAssertEqual(dest_ptr.v, source_ptr.v);
        for (UInt32 frame = 0; frame < frame_length; frame++) {
            Float32 value = source_ptr.f32[frame];
            Float32 test_value = yas::test::test_value(frame, 0, dest_channel_indices[ch]);
            XCTAssertEqual(value, test_value);
        }
    }
}

- (void)testInitWithInputChannelRoutes
{
    const UInt32 frame_length = 4;
    const UInt32 source_channels = 4;
    const UInt32 dest_channels = 2;
    const UInt32 bus = 0;
    const UInt32 sample_rate = 48000;
    const UInt32 source_channel_indices[2] = {2, 1};

    auto source_format = yas::audio_format::create(sample_rate, source_channels);
    auto source_buffer = yas::pcm_buffer::create(source_format, frame_length);
    yas::test::fill_test_values_to_buffer(source_buffer);

    auto channel_routes = std::vector<yas::channel_route_ptr>();
    for (UInt32 i = 0; i < dest_channels; i++) {
        channel_routes.push_back(yas::channel_route::create(bus, source_channel_indices[i], bus, i));
    }

    auto dest_format = yas::audio_format::create(sample_rate, dest_channels);
    auto dest_buffer = yas::pcm_buffer::create(dest_format, *source_buffer, channel_routes, false);

    for (UInt32 ch = 0; ch < dest_channels; ch++) {
        auto dest_ptr = dest_buffer->audio_ptr_at_index(ch);
        auto source_ptr = source_buffer->audio_ptr_at_index(source_channel_indices[ch]);
        XCTAssertEqual(dest_ptr.v, source_ptr.v);
        for (UInt32 frame = 0; frame < frame_length; frame++) {
            Float32 value = dest_ptr.f32[frame];
            Float32 testValue = yas::test::test_value(frame, 0, source_channel_indices[ch]);
            XCTAssertEqual(value, testValue);
        }
    }
}

#endif

@end
