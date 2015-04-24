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
    YASAudioUnitParameter *_parameter;
    YASAudioUnitNode *_node;
}

- (void)dealloc
{
    YASRelease(_nameLabel);
    YASRelease(_valueLabel);
    YASRelease(_valueSlider);
    YASRelease(_node);
    YASRelease(_parameter);

    _nameLabel = nil;
    _valueLabel = nil;
    _valueSlider = nil;
    _node = nil;
    _parameter = nil;

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
    [self setParameter:nil node:nil];
}

- (void)setParameter:(YASAudioUnitParameter *)parameter node:(YASAudioUnitNode *)node
{
    if (_parameter) {
        YASRelease(_parameter);
        _parameter = nil;
    }

    if (_node) {
        YASRelease(_node);
        _node = nil;
    }

    _parameter = YASRetain(parameter);
    _node = YASRetain(node);

    if (parameter) {
        self.nameLabel.text = parameter.name;
        self.valueSlider.minimumValue = parameter.minValue;
        self.valueSlider.maximumValue = parameter.maxValue;
    } else {
        self.nameLabel.text = nil;
        self.valueSlider.minimumValue = 0.0;
        self.valueSlider.maximumValue = 1.0;
    }

    if (node) {
        self.valueSlider.value = [node globalParameterValue:parameter.parameterID];
    } else {
        self.valueSlider.value = 0.0;
    }

    [self updateValueLabel];
}

- (void)updateValueLabel
{
    self.valueLabel.text = @([_node globalParameterValue:_parameter.parameterID]).stringValue;
}

- (IBAction)sliderValueChanged:(UISlider *)sender
{
    [_node setGlobalParameter:_parameter.parameterID value:sender.value];
    [self updateValueLabel];
}

@end
