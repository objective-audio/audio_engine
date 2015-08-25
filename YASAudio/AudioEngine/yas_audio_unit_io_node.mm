//
//  yas_audio_unit_io_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_unit_io_node.h"
#include "yas_audio_tap_node.h"
#include "yas_audio_time.h"

#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
namespace yas
{
    OSType const audio_unit_sub_type_default_io = kAudioUnitSubType_RemoteIO;
}
#elif TARGET_OS_MAC
#include "yas_audio_device.h"
namespace yas
{
    OSType const audio_unit_sub_type_default_io = kAudioUnitSubType_HALOutput;
}
#endif

using namespace yas;

class audio_unit_io_node::impl
{
   public:
    channel_map output_channel_map;
    channel_map input_channel_map;
};

audio_unit_io_node::audio_unit_io_node()
    : audio_unit_node({
          .componentType = kAudioUnitType_Output,
          .componentSubType = audio_unit_sub_type_default_io,
          .componentManufacturer = kAudioUnitManufacturer_Apple,
          .componentFlags = 0,
          .componentFlagsMask = 0,
      }),
      _impl(std::make_unique<impl>())
{
}

audio_unit_io_node::~audio_unit_io_node() = default;

void audio_unit_io_node::set_output_channel_map(const channel_map &channel_map)
{
    _impl->output_channel_map = channel_map;

    if (const auto unit = audio_unit()) {
        unit->set_channel_map(std::make_unique<std::vector<uint32_t>>(channel_map), kAudioUnitScope_Output);
    }
}

const channel_map &audio_unit_io_node::output_channel_map() const
{
    return _impl->output_channel_map;
}

void audio_unit_io_node::set_input_channel_map(const channel_map &channel_map)
{
    _impl->input_channel_map = channel_map;

    if (const auto unit = audio_unit()) {
        unit->set_channel_map(std::make_unique<std::vector<uint32_t>>(channel_map), kAudioUnitScope_Input);
    }
}

const channel_map &audio_unit_io_node::input_channel_map() const
{
    return _impl->input_channel_map;
}

void audio_unit_io_node::prepare_audio_unit()
{
    auto unit = audio_unit();
    unit->set_enable_output(true);
    unit->set_enable_input(true);
    unit->set_maximum_frames_per_slice(4096);
}

void audio_unit_io_node::prepare_parameters()
{
    super_class::prepare_parameters();

    auto unit = audio_unit();
    unit->set_channel_map(std::make_unique<channel_map>(_impl->output_channel_map), kAudioUnitScope_Output);
    unit->set_channel_map(std::make_unique<channel_map>(_impl->input_channel_map), kAudioUnitScope_Input);
}

bus_result audio_unit_io_node::next_available_output_bus() const
{
    auto result = super_class::next_available_output_bus();
    if (result && *result == 0) {
        return 1;
    }
    return result;
}

bool audio_unit_io_node::is_available_output_bus(const uint32_t bus_idx) const
{
    if (bus_idx == 1) {
        return super_class::is_available_output_bus(0);
    }
    return false;
}

#if TARGET_OS_IPHONE
/*
- (void)setOutputChannelAssignments:(NSArray *)outputChannelAssignments
{
    if (_outputChannelAssignments != outputChannelAssignments) {
        YASRelease(_outputChannelAssignments);
        _outputChannelAssignments = YASRetain(outputChannelAssignments);

        self.outputChannelMap =
        [self.class channelMapFromChannelAssignments:outputChannelAssignments scope:kAudioUnitScope_Output];
    }
}

- (void)setInputChannelAssignments:(NSArray *)inputChannelAssignments
{
    if (_inputChannelAssignments != inputChannelAssignments) {
        YASRelease(_inputChannelAssignments);
        _inputChannelAssignments = YASRetain(inputChannelAssignments);

        self.inputChannelMap =
        [self.class channelMapFromChannelAssignments:inputChannelAssignments scope:kAudioUnitScope_Input];
    }
}

+ (NSArray *)channelMapFromChannelAssignments:(NSArray *)channelAssignments scope:(AudioUnitScope)scope
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *routeDesc = audioSession.currentRoute;

    NSInteger channelCount = 0;
    NSArray *portDescriptions = nil;

    if (scope == kAudioUnitScope_Input) {
        channelCount = audioSession.inputNumberOfChannels;
        portDescriptions = routeDesc.inputs;
    } else if (scope == kAudioUnitScope_Output) {
        channelCount = audioSession.outputNumberOfChannels;
        portDescriptions = routeDesc.outputs;
    } else {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s Out of scope. scope(%@)", __PRETTY_FUNCTION__,
                             [NSString yas_stringWithAudioUnitScope:scope]]));
        return nil;
    }

    if (channelCount == 0) {
        YASRaiseWithReason(([NSString stringWithFormat:@"%s Channel count is 0.", __PRETTY_FUNCTION__]));
        return nil;
    }

    NSMutableArray *mutableChannelMap = [[NSMutableArray alloc] initWithCapacity:channelCount];

    for (AVAudioSessionPortDescription *portDescription in portDescriptions) {
        for (AVAudioSessionChannelDescription *channelDescription in portDescription.channels) {
            UInt32 idx = 0;
            UInt32 assignIndex = -1;

            for (AVAudioSessionChannelDescription *assignChannelDescription in channelAssignments) {
                if ([assignChannelDescription.owningPortUID isEqualToString:portDescription.UID] &&
                    assignChannelDescription.channelNumber == channelDescription.channelNumber) {
                    assignIndex = idx;
                    break;
                }
                idx++;
            }

            [mutableChannelMap addObject:@(assignIndex)];
        }
    }

    NSArray *channelMap = [mutableChannelMap copy];
    YASRelease(mutableChannelMap);

    return YASAutorelease(channelMap);
}
*/
#elif TARGET_OS_MAC

void audio_unit_io_node::set_device(const audio_device_sptr &device)
{
    if (!device) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    audio_unit()->set_current_device(device->audio_device_id());
}

audio_device_sptr audio_unit_io_node::device() const
{
    return audio_device::device_for_id(audio_unit()->current_device());
}

#endif

#pragma mark - audio_unit_output_node

audio_unit_output_node_sptr audio_unit_output_node::create()
{
    auto node = audio_unit_output_node_sptr(new audio_unit_output_node());
    prepare_for_create(node);
    return node;
}

void audio_unit_output_node::prepare_audio_unit()
{
    auto unit = audio_unit();
    unit->set_enable_output(true);
    unit->set_enable_input(false);
    unit->set_maximum_frames_per_slice(4096);
}

uint32_t audio_unit_output_node::input_bus_count() const
{
    return 1;
}

uint32_t audio_unit_output_node::output_bus_count() const
{
    return 0;
}

#pragma mark - audio_unit_input_node

class audio_unit_input_node::impl
{
   public:
    audio_pcm_buffer_sptr input_buffer;
    audio_time_sptr render_time;
};

audio_unit_input_node_sptr audio_unit_input_node::create()
{
    auto node = audio_unit_input_node_sptr(new audio_unit_input_node());
    prepare_for_create(node);
    node->_weak_this = node;
    return node;
}

audio_unit_input_node::audio_unit_input_node() : audio_unit_io_node(), _impl(std::make_unique<impl>())
{
}

void audio_unit_input_node::prepare_audio_unit()
{
    auto unit = audio_unit();
    unit->set_enable_output(false);
    unit->set_enable_input(true);
    unit->set_maximum_frames_per_slice(4096);
}

uint32_t audio_unit_input_node::input_bus_count() const
{
    return 0;
}

uint32_t audio_unit_input_node::output_bus_count() const
{
    return 1;
}

void audio_unit_input_node::update_connections()
{
    super_class::update_connections();

    auto unit = audio_unit();

    if (auto out_connection = output_connection(1)) {
        unit->attach_input_callback();

        auto input_buffer = audio_pcm_buffer::create(out_connection->format(), 4096);
        _impl->input_buffer = input_buffer;

        unit->set_input_callback([weak_node = _weak_this, input_buffer](render_parameters & render_parameters) {
            auto input_node = weak_node.lock();
            if (input_node && render_parameters.in_number_frames <= input_buffer->frame_capacity()) {
                input_buffer->set_frame_length(render_parameters.in_number_frames);
                render_parameters.io_data = input_buffer->audio_buffer_list();

                auto core = input_node->node_core();
                auto connection = core->output_connection(1);
                auto format = connection->format();
                auto time = audio_time::create(*render_parameters.io_time_stamp, format->sample_rate());
                input_node->set_render_time_on_render(time);

                if (auto io_unit = input_node->audio_unit()) {
                    render_parameters.in_bus_number = 1;
                    io_unit->audio_unit_render(render_parameters);
                }

                auto destination_node = connection->destination_node();

                if (auto *input_tap_node = dynamic_cast<audio_input_tap_node *>(destination_node.get())) {
                    input_tap_node->render(input_buffer, 0, time);
                }
            }
        });
    } else {
        unit->detach_input_callback();
        unit->set_input_callback(nullptr);
        _impl->input_buffer = nullptr;
    }
}

/*

 #pragma mark -

#pragma mark -

@implementation NSArray (YASAudioUnitIONode)

- (NSData *)yas_channelMapData
{
    NSUInteger count = self.count;
    if (count > 0) {
        NSMutableData *data = [NSMutableData dataWithLength:self.count * sizeof(UInt32)];
        UInt32 *ptr = data.mutableBytes;
        for (UInt32 i = 0; i < count; i++) {
            NSNumber *numberValue = self[i];
            ptr[i] = numberValue.uint32Value;
        }
        return data;
    } else {
        return nil;
    }
}

+ (NSArray *)yas_channelMapArrayWithData:(NSData *)data
{
    if (data.length > 0) {
        NSUInteger count = data.length / sizeof(UInt32);
        NSMutableArray *array = [NSMutableArray array];
        const UInt32 *ptr = data.bytes;
        for (UInt32 i = 0; i < count; i++) {
            [array addObject:@(ptr[i])];
        }
        return YASAutorelease([array copy]);
    } else {
        return nil;
    }
}

@end*/
