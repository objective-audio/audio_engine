//
//  yas_pcm_buffer_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

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
    auto pcm_buffer = yas::audio_pcm_buffer::create(format, 4);

    XCTAssertTrue(*format == *pcm_buffer->format());
    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssert(pcm_buffer->audio_ptr_at_index(1).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(2));
}

- (void)testCreateFloat32Interleaved1chBuffer
{
    auto pcm_buffer =
        yas::audio_pcm_buffer::create(yas::audio_format::create(48000.0, 1, yas::pcm_format::float32, true), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(1));
}

- (void)testCreateFloat64NonInterleaved2chBuffer
{
    auto pcm_buffer =
        yas::audio_pcm_buffer::create(yas::audio_format::create(48000.0, 2, yas::pcm_format::float64, false), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(2));
}

- (void)testCreateInt32Interleaved3chBuffer
{
    auto pcm_buffer =
        yas::audio_pcm_buffer::create(yas::audio_format::create(48000.0, 3, yas::pcm_format::fixed824, true), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(3));
}

- (void)testCreateInt16NonInterleaved4chBuffer
{
    auto pcm_buffer =
        yas::audio_pcm_buffer::create(yas::audio_format::create(48000.0, 4, yas::pcm_format::int16, false), 4);

    XCTAssert(pcm_buffer->audio_ptr_at_index(0).v);
    XCTAssertThrows(pcm_buffer->audio_ptr_at_index(4));
}

- (void)testSetFrameLength
{
    const UInt32 frame_capacity = 4;

    auto pcm_buffer = yas::audio_pcm_buffer::create(yas::audio_format::create(48000.0, 1), frame_capacity);
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
    auto buffer = yas::audio_pcm_buffer::create(format, frame_length);

    [self _testClearBuffer:buffer];
}

- (void)testClearDataInterleaved
{
    const UInt32 frame_length = 4;

    auto format = yas::audio_format::create(48000, 2, yas::pcm_format::float32, true);
    auto buffer = yas::audio_pcm_buffer::create(format, frame_length);

    [self _testClearBuffer:buffer];
}

- (void)_testClearBuffer:(yas::audio_pcm_buffer_sptr &)buffer
{
    yas::test::fill_test_values_to_buffer(buffer);

    XCTAssertTrue(yas::test::is_filled_buffer(buffer));

    buffer->reset();

    XCTAssertTrue(yas::test::is_cleard_buffer(buffer));

    yas::test::fill_test_values_to_buffer(buffer);

    buffer->clear(1, 2);

    const UInt32 buffer_count = buffer->format()->buffer_count();
    const UInt32 stride = buffer->format()->stride();

    for (UInt32 buffer_index = 0; buffer_index < buffer_count; buffer_index++) {
        Float32 *ptr = buffer->audio_ptr_at_index<Float32>(buffer_index);
        for (UInt32 frame = 0; frame < buffer->frame_length(); frame++) {
            for (UInt32 ch_idx = 0; ch_idx < stride; ch_idx++) {
                if (frame == 1 || frame == 2) {
                    XCTAssertEqual(ptr[frame * stride + ch_idx], 0);
                } else {
                    XCTAssertNotEqual(ptr[frame * stride + ch_idx], 0);
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

        auto from_buffer = yas::audio_pcm_buffer::create(format, frame_length);
        auto to_buffer = yas::audio_pcm_buffer::create(format, frame_length);

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
        auto from_buffer = yas::audio_pcm_buffer::create(from_format, frame_length);
        auto to_buffer = yas::audio_pcm_buffer::create(to_format, frame_length);

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
        auto from_buffer = yas::audio_pcm_buffer::create(format, from_frame_length);
        auto to_buffer = yas::audio_pcm_buffer::create(format, to_frame_length);

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

        auto from_buffer = yas::audio_pcm_buffer::create(format, from_frame_length);
        auto to_buffer = yas::audio_pcm_buffer::create(format, to_frame_length);

        yas::test::fill_test_values_to_buffer(from_buffer);

        const UInt32 length = 2;
        XCTAssertTrue(to_buffer->copy_from(from_buffer, from_start_frame, to_start_frame, length));

        for (UInt32 ch_idx = 0; ch_idx < channels; ch_idx++) {
            for (UInt32 i = 0; i < length; i++) {
                auto from_ptr = yas::test::data_ptr_from_buffer(from_buffer, ch_idx, from_start_frame + i);
                auto to_ptr = yas::test::data_ptr_from_buffer(to_buffer, ch_idx, to_start_frame + i);
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

        auto from_buffer = yas::audio_pcm_buffer::create(format, frame_length);
        auto to_buffer = yas::audio_pcm_buffer::create(format, frame_length);

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

        auto to_buffer = yas::audio_pcm_buffer::create(from_format, frame_length);
        auto from_buffer = yas::audio_pcm_buffer::create(to_format, frame_length);

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

    auto from_buffer = yas::audio_pcm_buffer::create(from_format, frame_length);
    auto to_buffer = yas::audio_pcm_buffer::create(to_format, frame_length);

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
        auto interleaved_buffer = yas::audio_pcm_buffer::create(interleaved_format, frame_length);
        auto deinterleaved_buffer = yas::audio_pcm_buffer::create(non_interleaved_format, frame_length);

        yas::test::fill_test_values_to_buffer(interleaved_buffer);

        XCTAssertNoThrow(deinterleaved_buffer->copy_from(interleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
        XCTAssertEqual(deinterleaved_buffer->frame_length(), frame_length);

        interleaved_buffer->reset();
        deinterleaved_buffer->reset();

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
        auto interleaved_buffer = yas::audio_pcm_buffer::create(interleaved_format, frame_length);
        auto deinterleaved_buffer = yas::audio_pcm_buffer::create(non_interleaved_format, frame_length);

        yas::test::fill_test_values_to_buffer(interleaved_buffer);

        XCTAssertNoThrow(interleaved_buffer->copy_to(deinterleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));

        interleaved_buffer->reset();
        deinterleaved_buffer->reset();

        yas::test::fill_test_values_to_buffer(deinterleaved_buffer);

        XCTAssertNoThrow(deinterleaved_buffer->copy_to(interleaved_buffer->audio_buffer_list()));
        XCTAssertTrue(yas::test::is_equal_buffer_flexibly(interleaved_buffer, deinterleaved_buffer));
    }
}

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)

- (void)testInitWithOutputChannelRoutes
{
    const UInt32 frame_length = 4;
    const UInt32 src_ch_count = 2;
    const UInt32 dst_ch_count = 4;
    const UInt32 bus_idx = 0;
    const UInt32 sample_rate = 48000;
    const UInt32 dest_channel_indices[2] = {3, 0};

    auto dest_format = yas::audio_format::create(sample_rate, dst_ch_count);
    auto dest_buffer = yas::audio_pcm_buffer::create(dest_format, frame_length);
    yas::test::fill_test_values_to_buffer(dest_buffer);

    auto channel_routes = std::vector<yas::channel_route_sptr>();
    for (UInt32 i = 0; i < src_ch_count; i++) {
        channel_routes.push_back(yas::channel_route::create(bus_idx, i, bus_idx, dest_channel_indices[i]));
    }

    auto source_format = yas::audio_format::create(sample_rate, src_ch_count);
    auto source_buffer =
        yas::audio_pcm_buffer::create(source_format, dest_buffer, channel_routes, yas::direction::output);

    for (UInt32 ch_idx = 0; ch_idx < src_ch_count; ++ch_idx) {
        auto dest_ptr = dest_buffer->audio_ptr_at_index(dest_channel_indices[ch_idx]);
        auto source_ptr = source_buffer->audio_ptr_at_index(ch_idx);
        XCTAssertEqual(dest_ptr.v, source_ptr.v);
        for (UInt32 frame = 0; frame < frame_length; frame++) {
            Float32 value = source_ptr.f32[frame];
            Float32 test_value = yas::test::test_value(frame, 0, dest_channel_indices[ch_idx]);
            XCTAssertEqual(value, test_value);
        }
    }
}

- (void)testInitWithInputChannelRoutes
{
    const UInt32 frame_length = 4;
    const UInt32 src_ch_count = 4;
    const UInt32 dst_ch_count = 2;
    const UInt32 bus_idx = 0;
    const UInt32 sample_rate = 48000;
    const UInt32 source_channel_indices[2] = {2, 1};

    auto source_format = yas::audio_format::create(sample_rate, src_ch_count);
    auto source_buffer = yas::audio_pcm_buffer::create(source_format, frame_length);
    yas::test::fill_test_values_to_buffer(source_buffer);

    auto channel_routes = std::vector<yas::channel_route_sptr>();
    for (UInt32 i = 0; i < dst_ch_count; i++) {
        channel_routes.push_back(yas::channel_route::create(bus_idx, source_channel_indices[i], bus_idx, i));
    }

    auto dest_format = yas::audio_format::create(sample_rate, dst_ch_count);
    auto dest_buffer = yas::audio_pcm_buffer::create(dest_format, source_buffer, channel_routes, yas::direction::input);

    for (UInt32 ch_idx = 0; ch_idx < dst_ch_count; ch_idx++) {
        auto dest_ptr = dest_buffer->audio_ptr_at_index(ch_idx);
        auto source_ptr = source_buffer->audio_ptr_at_index(source_channel_indices[ch_idx]);
        XCTAssertEqual(dest_ptr.v, source_ptr.v);
        for (UInt32 frame = 0; frame < frame_length; frame++) {
            Float32 value = dest_ptr.f32[frame];
            Float32 testValue = yas::test::test_value(frame, 0, source_channel_indices[ch_idx]);
            XCTAssertEqual(value, testValue);
        }
    }
}

#endif

- (void)testAllocateAudioBufferListInterleaved
{
    const UInt32 ch_idx = 2;
    const UInt32 size = 4;

    const auto pair = yas::allocate_audio_buffer_list(1, ch_idx, size);
    const yas::abl_uptr &abl = pair.first;

    XCTAssertEqual(abl->mNumberBuffers, 1);
    XCTAssertEqual(abl->mBuffers[0].mNumberChannels, ch_idx);
    XCTAssertEqual(abl->mBuffers[0].mDataByteSize, size);
    XCTAssertTrue(abl->mBuffers[0].mData != nullptr);
}

- (void)testAllocateAudioBufferListNonInterleaved
{
    const UInt32 buf = 2;
    const UInt32 size = 4;

    const auto pair = yas::allocate_audio_buffer_list(buf, 1, size);
    const yas::abl_uptr &abl = pair.first;

    XCTAssertTrue(abl != nullptr);
    XCTAssertEqual(abl->mNumberBuffers, buf);
    for (UInt32 i = 0; i < buf; i++) {
        XCTAssertEqual(abl->mBuffers[i].mNumberChannels, 1);
        XCTAssertEqual(abl->mBuffers[i].mDataByteSize, size);
        XCTAssertTrue(abl->mBuffers[i].mData != nullptr);
    }
}

- (void)testAllocateAudioBufferListWithoutData
{
    UInt32 buf = 1;
    UInt32 ch_idx = 1;

    const auto pair1 = yas::allocate_audio_buffer_list(buf, ch_idx, 0);
    const yas::abl_uptr &abl1 = pair1.first;

    XCTAssertTrue(abl1 != nullptr);
    for (UInt32 i = 0; i < buf; i++) {
        XCTAssertEqual(abl1->mBuffers[i].mNumberChannels, ch_idx);
        XCTAssertEqual(abl1->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl1->mBuffers[i].mData == nullptr);
    }

    const auto pair2 = yas::allocate_audio_buffer_list(buf, ch_idx);
    const yas::abl_uptr &abl2 = pair2.first;

    XCTAssertTrue(abl2 != nullptr);
    XCTAssertEqual(abl2->mNumberBuffers, buf);
    for (UInt32 i = 0; i < buf; i++) {
        XCTAssertEqual(abl2->mBuffers[i].mNumberChannels, ch_idx);
        XCTAssertEqual(abl2->mBuffers[i].mDataByteSize, 0);
        XCTAssertTrue(abl2->mBuffers[i].mData == nullptr);
    }
}

- (void)testIsEqualAudioBufferListStructureTrue
{
    auto pair1 = yas::allocate_audio_buffer_list(2, 2);
    auto pair2 = yas::allocate_audio_buffer_list(2, 2);
    yas::abl_uptr &abl1 = pair1.first;
    yas::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer1{0};
    std::vector<UInt8> buffer2{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer1.data();
    abl1->mBuffers[1].mData = abl2->mBuffers[1].mData = buffer2.data();

    XCTAssertTrue(yas::is_equal_structure(*abl1, *abl2));
}

- (void)testIsEqualAudioBufferListStructureDifferentBufferFalse
{
    auto pair1 = yas::allocate_audio_buffer_list(1, 1);
    auto pair2 = yas::allocate_audio_buffer_list(1, 1);
    yas::abl_uptr &abl1 = pair1.first;
    yas::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer1{0};
    std::vector<UInt8> buffer2{0};

    abl1->mBuffers[0].mData = buffer1.data();
    abl2->mBuffers[0].mData = buffer2.data();

    XCTAssertFalse(yas::is_equal_structure(*abl1, *abl2));
}

- (void)testIsEqualAudioBufferListStructureDifferentBuffersFalse
{
    auto pair1 = yas::allocate_audio_buffer_list(1, 1);
    auto pair2 = yas::allocate_audio_buffer_list(2, 1);
    yas::abl_uptr &abl1 = pair1.first;
    yas::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer.data();

    XCTAssertFalse(yas::is_equal_structure(*abl1, *abl2));
}

- (void)testIsEqualAudioBufferListStructureDifferentChannelsFalse
{
    auto pair1 = yas::allocate_audio_buffer_list(1, 1);
    auto pair2 = yas::allocate_audio_buffer_list(1, 2);
    yas::abl_uptr &abl1 = pair1.first;
    yas::abl_uptr &abl2 = pair2.first;

    std::vector<UInt8> buffer{0};

    abl1->mBuffers[0].mData = abl2->mBuffers[0].mData = buffer.data();

    XCTAssertFalse(yas::is_equal_structure(*abl1, *abl2));
}

@end
