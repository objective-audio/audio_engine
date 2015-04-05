//
//  YASAudioEngineSampleParameterCell.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineSampleParameterCell.h"
#import "YASAudio.h"

@interface YASAudioEngineSampleParameterCell ()

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *valueLabel;
@property (nonatomic, strong) IBOutlet UISlider *valueSlider;

@end

@implementation YASAudioEngineSampleParameterCell {
    YASAudioUnitParameter *_parameterInfo;
    YASAudioUnitNode *_node;
}

- (void)dealloc
{
    YASRelease(_nameLabel);
    YASRelease(_valueLabel);
    YASRelease(_valueSlider);
    YASRelease(_node);
    YASRelease(_parameterInfo);

    _nameLabel = nil;
    _valueLabel = nil;
    _valueSlider = nil;
    _node = nil;
    _parameterInfo = nil;

    YASSuperDealloc;
}

- (void)awakeFromNib
{
    [self reset];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self reset];
}

- (void)reset
{
    [self setParameterInfo:nil node:nil];
}

- (void)setParameterInfo:(YASAudioUnitParameter *)parameterInfo node:(YASAudioUnitNode *)node
{
    if (_parameterInfo) {
        YASRelease(_parameterInfo);
        _parameterInfo = nil;
    }

    if (_node) {
        YASRelease(_node);
        _node = nil;
    }

    _parameterInfo = YASRetain(parameterInfo);
    _node = YASRetain(node);

    if (parameterInfo) {
        self.nameLabel.text = parameterInfo.name;
        self.valueSlider.minimumValue = parameterInfo.minValue;
        self.valueSlider.maximumValue = parameterInfo.maxValue;
    } else {
        self.nameLabel.text = nil;
        self.valueSlider.minimumValue = 0.0;
        self.valueSlider.maximumValue = 1.0;
    }

    if (node) {
        self.valueSlider.value = [node globalParameterValue:parameterInfo.parameterID];
    } else {
        self.valueSlider.value = 0.0;
    }

    [self updateValueLabel];
}

- (void)updateValueLabel
{
    self.valueLabel.text = @([_node globalParameterValue:_parameterInfo.parameterID]).stringValue;
}

- (IBAction)sliderValueChanged:(UISlider *)sender
{
    [_node setGlobalParameter:_parameterInfo.parameterID value:sender.value];
    [self updateValueLabel];
}

@end
