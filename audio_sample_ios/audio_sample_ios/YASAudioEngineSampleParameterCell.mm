//
//  YASAudioEngineSampleParameterCell.m
//

#import "YASAudioEngineSampleParameterCell.h"
#import <audio/yas_audio_umbrella.h>

using namespace yas;

@interface YASAudioEngineSampleParameterCell ()

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *valueLabel;
@property (nonatomic, strong) IBOutlet UISlider *valueSlider;

@end

@implementation YASAudioEngineSampleParameterCell {
    std::optional<audio::engine::au> _au_opt;
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
    [super awakeFromNib];

    [self reset];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self reset];
}

- (void)reset {
    [self set_engine_au:std::nullopt index:0];
}

- (void)set_engine_au:(const std::optional<audio::engine::au> &)au_opt index:(uint32_t const)index {
    _au_opt = au_opt;
    _index = index;

    auto au = au_opt ? *au_opt : nullptr;
    if (au && au.global_parameters().count(_index)) {
        auto &parameter = au.global_parameters().at(_index);
        self.nameLabel.text = (__bridge NSString *)parameter.name();
        self.valueSlider.minimumValue = parameter.min_value();
        self.valueSlider.maximumValue = parameter.max_value();
        self.valueSlider.value = au.global_parameter_value(parameter.parameter_id());
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

    if (_au_opt) {
        auto &au = *_au_opt;
        if (au.global_parameters().count(_index)) {
            auto parameter_id = au.global_parameters().at(_index).parameter_id();
            value = au.global_parameter_value(parameter_id);
        }
    }

    self.valueLabel.text = @(value).stringValue;
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    if (_au_opt) {
        auto &au = *_au_opt;
        if (au && au.global_parameters().count(_index)) {
            auto parameter_id = au.global_parameters().at(_index).parameter_id();
            au.set_global_parameter_value(parameter_id, sender.value);
        }
    }

    [self updateValueLabel];
}

@end
