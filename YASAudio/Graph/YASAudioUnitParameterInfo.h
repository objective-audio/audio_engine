//
//  YASAudioUnitParameterInfo.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface YASAudioUnitParameterInfo : NSObject

@property (nonatomic, assign, readonly) AudioUnitParameterID parameterID;
@property (nonatomic, assign, readonly) AudioUnitScope scope;
@property (nonatomic, strong, readonly) NSString *unitName;
@property (nonatomic, assign, readonly) BOOL hasClump;
@property (nonatomic, assign, readonly) UInt32 clumpID;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) AudioUnitParameterUnit unit;
@property (nonatomic, assign, readonly) AudioUnitParameterValue minValue;
@property (nonatomic, assign, readonly) AudioUnitParameterValue maxValue;
@property (nonatomic, assign, readonly) AudioUnitParameterValue defaultValue;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAudioUnitParameterInfo:(const AudioUnitParameterInfo *)info
                                   parameterID:(const AudioUnitParameterID)parameterID
                                         scope:(const AudioUnitScope)scope NS_DESIGNATED_INITIALIZER;

@end
