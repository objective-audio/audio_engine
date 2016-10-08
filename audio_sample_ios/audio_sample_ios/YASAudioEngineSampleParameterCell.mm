//
//  YASAudioEngineSampleParameterCell.m
//

#import "YASAudioEngineSampleParameterCell.h"
#import "yas_audio.h"

using namespace yas;

@interface YASAudioEngineSampleParameterCell ()

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *valueLabel;
@property (nonatomic, strong) IBOutlet UISlider *valueSlider;

@end

@implementation YASAudioEngineSampleParameterCell {
    std::experimental::optional<audio::unit_node> _node_opt;
    uint32_t _index;
}

- (void)dealloc {
    yas_release(_nameLabel);
    yas_release(_valueLabel);
    yas_release(_valueSlider);

    _nameLabel = nil;
    _valueLabel = nil;
    _valueSlider = nil;

    yas_super_dealloc();
}

- (void)awakeFromNib {
    [self reset];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self reset];
}

- (void)reset {
    [self set_node:yas::nullopt index:0];
}

- (void)set_node:(const std::experimental::optional<audio::unit_node> &)node_opt index:(uint32_t const)index {
    _node_opt = node_opt;
    _index = index;

    auto node = node_opt ? *node_opt : nullptr;
    if (node && node.global_parameters().count(_index)) {
        auto &parameter = node.global_parameters().at(_index);
        self.nameLabel.text = (__bridge NSString *)parameter.name();
        self.valueSlider.minimumValue = parameter.min_value();
        self.valueSlider.maximumValue = parameter.max_value();
        self.valueSlider.value = node.global_parameter_value(parameter.parameter_id());
    } else {
        self.nameLabel.text = nil;
        self.valueSlider.minimumValue = 0.0;
        self.valueSlider.maximumValue = 1.0;
        self.valueSlider.value = 0.0;
    }

    [self updateValueLabel];
}

- (void)updateValueLabel {
    float value = 0;

    if (_node_opt) {
        auto &node = *_node_opt;
        if (node.global_parameters().count(_index)) {
            auto parameter_id = node.global_parameters().at(_index).parameter_id();
            value = node.global_parameter_value(parameter_id);
        }
    }

    self.valueLabel.text = @(value).stringValue;
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    if (_node_opt) {
        auto &node = *_node_opt;
        if (node && node.global_parameters().count(_index)) {
            auto parameter_id = node.global_parameters().at(_index).parameter_id();
            node.set_global_parameter_value(parameter_id, sender.value);
        }
    }

    [self updateValueLabel];
}

@end
