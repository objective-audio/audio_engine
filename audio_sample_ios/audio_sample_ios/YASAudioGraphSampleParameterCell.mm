//
//  YASAudioGraphSampleParameterCell.m
//

#import "YASAudioGraphSampleParameterCell.h"
#import <audio/yas_audio_umbrella.h>
#import <objc_utils/yas_objc_macros.h>

using namespace yas;

@interface YASAudioGraphSampleParameterCell ()

@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *valueLabel;
@property (nonatomic, strong) IBOutlet UISlider *valueSlider;

@end

@implementation YASAudioGraphSampleParameterCell {
    audio::avf_au_parameter_ptr _parameter;
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
    self->_parameter = nullptr;

    self.nameLabel.text = nil;
    self.valueSlider.minimumValue = 0.0;
    self.valueSlider.maximumValue = 1.0;
    self.valueSlider.value = 0.0;

    [self updateValueLabel];
}

- (void)set_parameter:(yas::audio::avf_au_parameter_ptr const &)parameter {
    self->_parameter = parameter;

    self.nameLabel.text = (__bridge NSString *)to_cf_object(parameter->display_name());
    self.valueSlider.minimumValue = parameter->min_value();
    self.valueSlider.maximumValue = parameter->max_value();
    self.valueSlider.value = parameter->value();

    [self updateValueLabel];
}

- (void)updateValueLabel {
    if (auto const &parameter = self->_parameter) {
        auto value_string = std::to_string(parameter->value());

        if (auto const unit_name = parameter->unit_name()) {
            value_string += " ";
            value_string += unit_name.value();
        }

        self.valueLabel.text = (__bridge NSString *)to_cf_object(value_string);
    } else {
        self.valueLabel.text = @"-";
    }
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    if (auto &parameter = self->_parameter) {
        parameter->set_value(sender.value);
        [self updateValueLabel];
    }
}

@end
