//
//  AppDelegate.m
//

#import "AppDelegate.h"
#include <audio/yas_audio_umbrella.hpp>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    yas_audio_set_log_enabled(true);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
