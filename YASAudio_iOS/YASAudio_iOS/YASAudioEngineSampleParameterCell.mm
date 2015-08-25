//
//  YASAudioEngineSampleParameterCell.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineSampleParameterCell.h"
#import "yas_audio.h"

@interface YASAudioEngineSampleParameterCell ()

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *valueLabel;
@property (nonatomic, strong) IBOutlet UISlider *valueSlider;

@end

@implementation YASAudioEngineSampleParameterCell {
    yas::audio_unit_node_sptr _node;
    uint32_t _index;
}

- (void)dealloc
{
    YASRelease(_nameLabel);
    YASRelease(_valueLabel);
    YASRelease(_valueSlider);

    _nameLabel = nil;
    _valueLabel = nil;
    _valueSlider = nil;

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
    [self set_node:nullptr index:0];
}

- (void)set_node:(const yas::audio_unit_node_sptr &)node index:(const uint32_t)index
{
    _node = node;
    _index = index;

    if (_node && _node->global_parameters().count(_index)) {
        auto &parameter = _node->global_parameters().at(_index);
        self.nameLabel.text = (__bridge NSString *)(yas::to_cf_object(parameter.name()));
        self.valueSlider.minimumValue = parameter.min_value();
        self.valueSlider.maximumValue = parameter.max_value();
        self.valueSlider.value = node->global_parameter_value(parameter.parameter_id());
    } else {
        self.nameLabel.text = nil;
        self.valueSlider.minimumValue = 0.0;
        self.valueSlider.maximumValue = 1.0;
        self.valueSlider.value = 0.0;
    }

    [self updateValueLabel];
}

- (void)updateValueLabel
{
    Float32 value = 0;

    if (_node && _node->global_parameters().count(_index)) {
        auto parameter_id = _node->global_parameters().at(_index).parameter_id();
        value = _node->global_parameter_value(parameter_id);
    }

    self.valueLabel.text = @(value).stringValue;
}

- (IBAction)sliderValueChanged:(UISlider *)sender
{
    if (_node && _node->global_parameters().count(_index)) {
        auto parameter_id = _node->global_parameters().at(_index).parameter_id();
        _node->set_global_parameter_value(parameter_id, sender.value);
    }

    [self updateValueLabel];
}

@end
