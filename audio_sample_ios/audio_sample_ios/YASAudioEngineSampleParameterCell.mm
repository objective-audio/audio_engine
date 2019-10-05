//
//  YASAudioEngineSampleParameterCell.m
//

#import "YASAudioEngineSampleParameterCell.h"
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_macros.h>

using namespace yas;

@interface YASAudioEngineSampleParameterCell ()

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *valueLabel;
@property (nonatomic, strong) IBOutlet UISlider *valueSlider;

@end

@implementation YASAudioEngineSampleParameterCell {
    audio::engine::au_ptr _au_opt;
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
    [self set_engine_au:nullptr index:0];
}

- (void)set_engine_au:(audio::engine::au_ptr const &)au_opt index:(uint32_t const)index {
    _au_opt = au_opt;
    _index = index;

    if (au_opt && au_opt->global_parameters().count(_index)) {
        auto &parameter = au_opt->global_parameters().at(_index);
        self.nameLabel.text = (__bridge NSString *)parameter.cf_name();
        self.valueSlider.minimumValue = parameter.min_value;
        self.valueSlider.maximumValue = parameter.max_value;
        self.valueSlider.value = au_opt->global_parameter_value(parameter.parameter_id);
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
            auto const parameter_id = au.global_parameters().at(_index).parameter_id;
            value = au.global_parameter_value(parameter_id);
        }
    }

    self.valueLabel.text = @(value).stringValue;
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    if (_au_opt) {
        if (_au_opt->global_parameters().count(_index)) {
            auto const parameter_id = _au_opt->global_parameters().at(_index).parameter_id;
            _au_opt->set_global_parameter_value(parameter_id, sender.value);
        }
    }

    [self updateValueLabel];
}

@end
