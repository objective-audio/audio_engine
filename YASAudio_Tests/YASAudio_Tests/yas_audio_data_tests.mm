//
//  yas_audio_data_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#include "yas_audio_data.h"
#include "yas_audio_format.h"
#include "yas_audio_channel_route.h"
#include "yas_audio_test_utils.h"
#include <memory>

@interface yas_audio_data_tests : XCTestCase

@end

@implementation yas_audio_data_tests

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
    auto audio_data = yas::audio_data::create(format, 4);

    XCTAssertTrue(*format == *audio_data->format());
    XCTAssert(audio_data->audio_ptr_at_buffer(0).v);
    XCTAssert(audio_data->audio_ptr_at_buffer(1).v);
    XCTAssertThrows(audio_data->audio_ptr_at_buffer(2));
}

- (void)testCreateFloat32Interleaved1chBuffer
{
    auto audio_data = yas::audio_data::create(yas::audio_format::create(48000.0, 1, yas::pcm_format::float32, true), 4);

    XCTAssert(audio_data->audio_ptr_at_buffer(0).v);
    XCTAssertThrows(audio_data->audio_ptr_at_buffer(1));
}

- (void)testCreateFloat64NonInterleaved2chBuffer
{
    auto audio_data =
        yas::audio_data::create(yas::audio_format::create(48000.0, 2, yas::pcm_format::float64, false), 4);

    XCTAssert(audio_data->audio_ptr_at_buffer(0).v);
    XCTAssertThrows(audio_data->audio_ptr_at_buffer(2));
}

- (void)testCreateInt32Interleaved3chBuffer
{
    auto audio_data =
        yas::audio_data::create(yas::audio_format::create(48000.0, 3, yas::pcm_format::fixed824, true), 4);

    XCTAssert(audio_data->audio_ptr_at_buffer(0).v);
    XCTAssertThrows(audio_data->audio_ptr_at_buffer(3));
}

- (void)testCreateInt16NonInterleaved4chBuffer
{
    auto audio_data = yas::audio_data::create(yas::audio_format::create(48000.0, 4, yas::pcm_format::int16, false), 4);

    XCTAssert(audio_data->audio_ptr_at_buffer(0).v);
    XCTAssertThrows(audio_data->audio_ptr_at_buffer(4));
}

- (void)testSetFrameLength
{
    const UInt32 frame_capacity = 4;

    auto audio_data = yas::audio_data::create(yas::audio_format::create(48000.0, 1), frame_capacity);
    const auto &format = audio_data->format();

    XCTAssertEqual(audio_data->frame_length(), frame_capacity);
    XCTAssertEqual(audio_data->audio_buffer_list()->mBuffers[0].mDataByteSize,
                   frame_capacity * format->buffer_frame_byte_count());

    audio_data->set_frame_length(2);

    XCTAssertEqual(audio_data->frame_length(), 2);
    XCTAssertEqual(audio_data->audio_buffer_list()->mBuffers[0].mDataByteSize, 2 * format->buffer_frame_byte_count());

    audio_data->set_frame_length(0);

    XCTAssertEqual(audio_data->frame_length(), 0);
    XCTAssertEqual(audio_data->audio_buffer_list()->mBuffers[0].mDataByteSize, 0);

    XCTAssertThrows(audio_data->set_frame_length(5));
    XCTAssertEqual(audio_data->frame_length(), 0);
}

- (void)testClearDataNonInterleaved
{
    const UInt32 frame_length = 4;

    auto format = yas::audio_format::create(48000.0, 2, yas::pcm_format::float32, false);
    auto data = yas::audio_data::create(format, frame_length);

    [self _testClearData:data];
}

- (void)testClearDataInterleaved
{
    const UInt32 frame_length = 4;

    auto format = yas::audio_format::create(48000, 2, yas::pcm_format::float32, true);
    auto data = yas::audio_data::create(format, frame_length);

    [self _testClearData:data];
}

- (void)_testClearData:(yas::audio_data_ptr &)data
{
    yas::test::fill_test_values_to_data(data);

    XCTAssertTrue(yas::test::is_filled_data(data));

    data->clear();

    XCTAssertTrue(yas::test::is_cleard_data(data));

    yas::test::fill_test_values_to_data(data);

    data->clear(1, 2);

    const UInt32 buffer_count = data->format()->buffer_count();
    const UInt32 stride = data->format()->stride();

    for (UInt32 buffer = 0; buffer < buffer_count; buffer++) {
        Float32 *ptr = data->audio_ptr_at_buffer(buffer).f32;
        for (UInt32 frame = 0; frame < data->frame_length(); frame++) {
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

        auto from_data = yas::audio_data::create(format, frame_length);
        auto to_data = yas::audio_data::create(format, frame_length);

        yas::test::fill_test_values_to_data(from_data);

        XCTAssertTrue(yas::copy_data(from_data, to_data));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(from_data, to_data));
    }
}

- (void)testCopyDataDifferentInterleavedFormatFailed
{
    const Float64 sample_rate = 48000;
    const UInt32 frame_length = 4;
    const UInt32 channels = 3;

    for (auto i = static_cast<int>(yas::pcm_format::float32); i <= static_cast<int>(yas::pcm_format::fixed824); ++i) {
        const auto pcm_format = static_cast<yas::pcm_format>(i);
        auto from_format = yas::audio_format::create(sample_rate, channels, pcm_format, true);
        auto to_format = yas::audio_format::create(sample_rate, channels, pcm_format, false);
        auto from_data = yas::audio_data::create(from_format, frame_length);
        auto to_data = yas::audio_data::create(to_format, frame_length);

        yas::test::fill_test_values_to_data(from_data);

        XCTAssertFalse(yas::copy_data(from_data, to_data));
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
        auto from_data = yas::audio_data::create(format, from_frame_length);
        auto to_data = yas::audio_data::create(format, to_frame_length);

        yas::test::fill_test_values_to_data(from_data);

        XCTAssertFalse(yas::copy_data(from_data, to_data, 0, 0, from_frame_length));
        XCTAssertTrue(yas::copy_data(from_data, to_data, 0, 0, to_frame_length));
        XCTAssertFalse(yas::test::is_equal_data_flexibly(from_data, to_data));
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

        auto from_data = yas::audio_data::create(format, from_frame_length);
        auto to_data = yas::audio_data::create(format, to_frame_length);

        yas::test::fill_test_values_to_data(from_data);

        const UInt32 length = 2;
        auto result = yas::copy_data(from_data, to_data, from_start_frame, to_start_frame, length);
        XCTAssertTrue(result);

        for (UInt32 ch = 0; ch < channels; ch++) {
            for (UInt32 i = 0; i < length; i++) {
                yas::audio_pointer fromPtr = yas::test::data_ptr_from_data(from_data, ch, from_start_frame + i);
                yas::audio_pointer toPtr = yas::test::data_ptr_from_data(to_data, ch, to_start_frame + i);
                XCTAssertEqual(memcmp(fromPtr.v, toPtr.v, format->sample_byte_count()), 0);
                BOOL isFromNotZero = NO;
                BOOL isToNotZero = NO;
                for (UInt32 j = 0; j < format->sample_byte_count(); j++) {
                    if (fromPtr.u8[j] != 0) {
                        isFromNotZero = YES;
                    }
                    if (toPtr.u8[j] != 0) {
                        isToNotZero = YES;
                    }
                }
                XCTAssertTrue(isFromNotZero);
                XCTAssertTrue(isToNotZero);
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

        auto from_data = yas::audio_data::create(format, frame_length);
        auto to_data = yas::audio_data::create(format, frame_length);

        yas::test::fill_test_values_to_data(from_data);

        XCTAssertNoThrow(yas::copy_data_flexibly(from_data, to_data));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(from_data, to_data));
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

        auto to_data = yas::audio_data::create(from_format, frame_length);
        auto from_data = yas::audio_data::create(to_format, frame_length);

        yas::test::fill_test_values_to_data(from_data);

        XCTAssertNoThrow(yas::copy_data_flexibly(from_data, to_data));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(from_data, to_data));
        XCTAssertEqual(to_data->frame_length(), frame_length);
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

    auto from_data = yas::audio_data::create(from_format, frame_length);
    auto to_data = yas::audio_data::create(to_format, frame_length);

    XCTAssertFalse(yas::copy_data_flexibly(from_data, to_data));
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
        auto interleaved_data = yas::audio_data::create(interleaved_format, frame_length);
        auto deinterleaved_data = yas::audio_data::create(non_interleaved_format, frame_length);

        yas::test::fill_test_values_to_data(interleaved_data);

        XCTAssertNoThrow(yas::copy_data_flexibly(interleaved_data->audio_buffer_list(), deinterleaved_data));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(interleaved_data, deinterleaved_data));
        XCTAssertEqual(deinterleaved_data->frame_length(), frame_length);

        interleaved_data->clear();
        deinterleaved_data->clear();

        yas::test::fill_test_values_to_data(deinterleaved_data);

        XCTAssertNoThrow(yas::copy_data_flexibly(deinterleaved_data->audio_buffer_list(), interleaved_data));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(interleaved_data, deinterleaved_data));
        XCTAssertEqual(interleaved_data->frame_length(), frame_length);
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
        auto interleaved_data = yas::audio_data::create(interleaved_format, frame_length);
        auto deinterleaved_data = yas::audio_data::create(non_interleaved_format, frame_length);

        yas::test::fill_test_values_to_data(interleaved_data);

        XCTAssertNoThrow(yas::copy_data_flexibly(interleaved_data, deinterleaved_data->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(interleaved_data, deinterleaved_data));

        interleaved_data->clear();
        deinterleaved_data->clear();

        yas::test::fill_test_values_to_data(deinterleaved_data);

        XCTAssertNoThrow(yas::copy_data_flexibly(deinterleaved_data, interleaved_data->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_data_flexibly(interleaved_data, deinterleaved_data));
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
    auto dest_data = yas::audio_data::create(dest_format, frame_length);
    yas::test::fill_test_values_to_data(dest_data);

    auto channel_routes = std::vector<yas::channel_route_ptr>();
    for (UInt32 i = 0; i < source_channels; i++) {
        channel_routes.push_back(yas::channel_route::create(bus, i, bus, dest_channel_indices[i]));
    }

    auto source_format = yas::audio_format::create(sample_rate, source_channels);
    auto source_data = yas::audio_data::create(source_format, *dest_data, channel_routes, true);

    for (UInt32 ch = 0; ch < source_channels; ++ch) {
        yas::audio_pointer dest_ptr = dest_data->audio_ptr_at_buffer(dest_channel_indices[ch]);
        yas::audio_pointer source_ptr = source_data->audio_ptr_at_buffer(ch);
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
    auto source_data = yas::audio_data::create(source_format, frame_length);
    yas::test::fill_test_values_to_data(source_data);

    auto channel_routes = std::vector<yas::channel_route_ptr>();
    for (UInt32 i = 0; i < dest_channels; i++) {
        channel_routes.push_back(yas::channel_route::create(bus, source_channel_indices[i], bus, i));
    }

    auto dest_format = yas::audio_format::create(sample_rate, dest_channels);
    auto dest_data = yas::audio_data::create(dest_format, *source_data, channel_routes, false);

    for (UInt32 ch = 0; ch < dest_channels; ch++) {
        yas::audio_pointer dest_ptr = dest_data->audio_ptr_at_buffer(ch);
        yas::audio_pointer source_ptr = source_data->audio_ptr_at_buffer(source_channel_indices[ch]);
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
