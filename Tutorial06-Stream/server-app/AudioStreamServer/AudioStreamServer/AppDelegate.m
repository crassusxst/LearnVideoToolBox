//
//  AppDelegate.m
//  AudioStreamServer
//
//  Created by 林伟池 on 2017/4/1.
//  Copyright © 2017年 loying. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (IBAction)quit:(id)sender {
    NSLog(@"断开与服务器链接");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"closeServer" object:nil];
    [NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
