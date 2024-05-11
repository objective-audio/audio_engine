//
//  YASAudioGraphEffectsSampleViewController.mm
//

#import "YASAudioGraphEffectsSampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio-engine/umbrella.h>
#import "YASAudioGraphEffectsSampleEditViewController.h"
#import "YASViewControllerUtils.h"

using namespace yas;

namespace yas::sample {
enum class graph_effects_section {
    none,
    effects,
};
static std::size_t constexpr graph_effects_section_count = 2;

static const AudioComponentDescription baseAcd = {.componentType = kAudioUnitType_Effect,
                                                  .componentSubType = 0,
                                                  .componentManufacturer = kAudioUnitManufacturer_Apple,
                                                  .componentFlags = 0,
                                                  .componentFlagsMask = 0};

static std::vector<audio::avf_au_ptr> effect_units() {
    std::vector<audio::avf_au_ptr> units;

    AudioComponent component = NULL;

    while (true) {
        component = AudioComponentFindNext(component, &baseAcd);
        if (component != NULL) {
            AudioComponentDescription acd;
            raise_if_raw_audio_error(AudioComponentGetDescription(component, &acd));

            units.push_back(audio::avf_au::make_shared(acd));
        } else {
            break;
        }
    }

    return units;
}

struct effects_vc_cpp {
    std::optional<uint32_t> index = std::nullopt;
    audio::ios_session_ptr const session = audio::ios_session::shared();
    audio::ios_device_ptr const device = audio::ios_device::make_shared(this->session);
    audio::graph_ptr const graph = audio::graph::make_shared();
    audio::graph_tap_ptr const tap = audio::graph_tap::make_shared();
    std::optional<audio::graph_connection_ptr> through_connection = std::nullopt;
    std::optional<audio::graph_avf_au_ptr> effect_au = std::nullopt;
    std::vector<audio::avf_au_ptr> units = effect_units();
    observing::canceller_pool _pool;

    void setup() {
        this->graph->add_io(this->device);

        if (this->units.size() == 0) {
            AudioComponent component = NULL;

            while (true) {
                component = AudioComponentFindNext(component, &baseAcd);
                if (component != NULL) {
                    AudioComponentDescription acd;
                    raise_if_raw_audio_error(AudioComponentGetDescription(component, &acd));

                    this->units.push_back(audio::avf_au::make_shared(acd));
                } else {
                    break;
                }
            }
        }

        double phase = 0;

        auto tap_render_handler = [phase](audio::node_render_args const &args) mutable {
            auto &buffer = args.buffer;

            buffer->clear();

            double const start_phase = phase;
            double const phase_per_frame = 1000.0 / buffer->format().sample_rate() * audio::math::two_pi;

            auto each = audio::make_each_data<float>(*buffer);
            auto const length = buffer->frame_length();

            while (yas_each_data_next_ch(each)) {
                if (yas_each_data_index(each) == 0) {
                    phase = audio::math::fill_sine(yas_each_data_ptr(each), length, start_phase, phase_per_frame);
                }
            }
        };

        this->tap->set_render_handler(tap_render_handler);

        this->replace_effect_au(nullptr);
    }

    void dispose() {
        if (this->graph) {
            this->graph->stop();
        }

        this->session->deactivate();
    }

    void replace_effect_au(const AudioComponentDescription *acd) {
        this->_pool.cancel();

        if (auto const &effect_au = this->effect_au) {
            this->graph->disconnect(effect_au.value()->node);
            this->effect_au = std::nullopt;
        }

        if (auto const &connection = this->through_connection) {
            this->graph->disconnect(connection.value());
            this->through_connection = std::nullopt;
        }

        auto format = audio::format({.sample_rate = this->session->sample_rate(), .channel_count = 2});

        if (acd) {
            auto const effect_au = audio::graph_avf_au::make_shared(*acd);

            this->effect_au = effect_au;

            effect_au
                ->observe_load_state([this, format](auto const &state) {
                    if (state == audio::avf_au::load_state::loaded) {
                        this->graph->connect(this->effect_au.value()->node, this->graph->io().value()->output_node,
                                             format);
                        this->graph->connect(tap->node, this->effect_au.value()->node, format);
                    }
                })
                .sync()
                ->add_to(this->_pool);
        } else {
            this->through_connection = graph->connect(this->tap->node, this->graph->io().value()->output_node, format);
        }
    }
};
}  // namespace yas::sample

@interface YASAudioGraphEffectsSampleViewController ()
@end

@implementation YASAudioGraphEffectsSampleViewController {
    sample::effects_vc_cpp _cpp;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        [self setup];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.isMovingFromParentViewController) {
        self->_cpp.dispose();
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (!self->_cpp.index) {
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioGraphEffectsSampleEditViewController class]]) {
        YASAudioGraphEffectsSampleEditViewController *controller = destinationViewController;
        [controller set_graph_au:self->_cpp.effect_au.value()];
    }
}

- (void)setup {
    self->_cpp.session->set_category(audio::ios_session::category::playback);

    if (auto const result = self->_cpp.session->activate(); !result) {
        NSString *errorMessage = (__bridge NSString *)to_cf_object(result.error());
        [YASViewControllerUtils showErrorAlertWithMessage:errorMessage toViewController:self];
        return;
    }

    self->_cpp.setup();

    if (auto start_result = self->_cpp.graph->start_render()) {
        [self.tableView reloadData];
    } else {
        auto const error_string = to_string(start_result.error());
        NSString *errorMessage = (__bridge NSString *)to_cf_object(error_string);
        [YASViewControllerUtils showErrorAlertWithMessage:errorMessage toViewController:self];
    }
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self->_cpp.graph) {
        return sample::graph_effects_section_count;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (sample::graph_effects_section(section)) {
        case sample::graph_effects_section::none:
            return 1;
        case sample::graph_effects_section::effects:
            return self->_cpp.units.size();
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (sample::graph_effects_section(section)) {
        case sample::graph_effects_section::effects:
            return @"Effects";
        case sample::graph_effects_section::none:
            return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self _dequeueCellWithIndexPath:indexPath];

    switch (sample::graph_effects_section(indexPath.section)) {
        case sample::graph_effects_section::none: {
            cell.textLabel.text = @"None";
            if (!self->_cpp.index) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } break;
        case sample::graph_effects_section::effects: {
            auto const &unit = self->_cpp.units.at(indexPath.row);
            cell.textLabel.text = (__bridge NSString *)to_cf_object(unit->audio_unit_name());
            if (self->_cpp.index && indexPath.row == self->_cpp.index.value()) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } break;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (sample::graph_effects_section(indexPath.section)) {
        case sample::graph_effects_section::none: {
            self->_cpp.index = std::nullopt;
            self->_cpp.replace_effect_au(nullptr);
        } break;
        case sample::graph_effects_section::effects: {
            self->_cpp.index = static_cast<uint32_t>(indexPath.row);
            AudioComponentDescription acd = sample::baseAcd;
            auto const &unit = self->_cpp.units.at(indexPath.row);
            acd.componentSubType = unit->componentDescription().componentSubType;
            self->_cpp.replace_effect_au(&acd);
        } break;
    }

    [tableView
          reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sample::graph_effects_section_count)]
        withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Private

- (UITableViewCell *)_dequeueCellWithIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

@end
