//
//  YASAudioReloadViewController.mm
//

#import "YASAudioReloadViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <audio/yas_audio_umbrella.h>
#import "YASViewControllerUtils.h"
#import "yas_audio_sample_kernel.h"

using namespace yas;

namespace yas::sample {
struct reload_vc_cpp {
    audio::ios_session_ptr const session;
    audio::io_device_ptr const device;
    audio::graph_ptr const graph;
    audio::graph_tap_ptr const tap;
    audio::sample::kernel_ptr const kernel;

    reload_vc_cpp()
        : session(audio::ios_session::shared()),
          device(audio::ios_device::make_renewable_device(this->session)),
          graph(audio::graph::make_shared()),
          tap(audio::graph_tap::make_shared()),
          kernel(audio::sample::kernel::make_shared()) {
    }

    std::optional<std::string> setup() {
        this->session->set_category(audio::ios_session::category::playback);

        if (auto const result = this->session->activate(); !result) {
            return result.error();
        }

        this->graph->add_io(this->device);

        this->kernel->set_sine_volume(0.1);
        this->kernel->set_sine_frequency(1000.0);

        this->tap->set_render_handler([kernel = this->kernel](audio::graph_node::render_args args) {
            kernel->process(nullptr, args.buffer ? args.buffer.get() : nullptr);
        });

        this->update_connection();

        this->device->io_device_chain()
            .perform([this](auto const &method) {
                this->graph->stop();
                this->session->deactivate();
                if (auto result = this->session->activate()) {
                    this->update_connection();
                    this->graph->start_render();
                }
            })
            .end()
            ->add_to(this->_pool);

        if (auto const result = this->graph->start_render(); !result) {
            return to_string(result.error());
        }

        return std::nullopt;
    }

    void reactivateSession() {
        this->graph->stop();
        this->session->deactivate();
        auto result = this->session->activate();
        this->graph->start_render();
    }

    void dispose() {
        this->graph->remove_io();

        this->session->deactivate();
    }

    void update_connection() {
        this->graph->disconnect(this->tap->node());

        if (auto const &io = this->graph->io()) {
            if (auto const &device = io.value()->raw_io()->device()) {
                if (auto const &format = device.value()->output_format()) {
                    this->graph->connect(this->tap->node(), io.value()->node(), format.value());
                }
            }
        }
    }

   private:
    chaining::observer_pool _pool;
};
}

@interface YASAudioReloadViewController ()

@end

@implementation YASAudioReloadViewController {
    sample::reload_vc_cpp _cpp;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.isMovingToParentViewController) {
        if (auto const error_message = self->_cpp.setup()) {
            [YASViewControllerUtils showErrorAlertWithMessage:(__bridge NSString *)to_cf_object(error_message.value())
                                             toViewController:self];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (self.isMovingFromParentViewController) {
        self->_cpp.dispose();
    }

    [super viewWillDisappear:animated];
}

- (IBAction)notifyLost:(UIButton *)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:AVAudioSessionMediaServicesWereLostNotification
                                                        object:[AVAudioSession sharedInstance]];
}

- (IBAction)notifyRouteChange:(UIButton *)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:AVAudioSessionRouteChangeNotification
                                                        object:[AVAudioSession sharedInstance]];
}

- (IBAction)reactivateSession:(UIButton *)sender {
    self->_cpp.reactivateSession();
}

@end
