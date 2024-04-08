//
//  YASViewControllerUtils.m
//

#import "YASViewControllerUtils.h"

@interface YASViewControllerUtils ()

@end

@implementation YASViewControllerUtils

+ (void)showErrorAlertWithMessage:(NSString *)message toViewController:(UIViewController *)viewController {
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:message
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [viewController.navigationController
                                                         popViewControllerAnimated:YES];
                                                 }]];
    [viewController presentViewController:controller animated:YES completion:NULL];
}

@end
