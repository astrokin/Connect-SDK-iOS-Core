//
// Created by Jeremy White on 4/14/14.
// Copyright (c) 2014 LG Electronics. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DeviceServiceReachability.h"
#import "CSNetworkHelper.h"
#import "ConnectSDKLog.h"

@implementation DeviceServiceReachability
{
    NSTimer *_runTimer;
}

- (instancetype) initWithTargetURL:(NSURL *)targetURL
{
    self = [super init];
    
    if (self)
    {
        _running = NO;
        _targetURL = targetURL;
    }
    
    return self;
}

+ (instancetype) reachabilityWithTargetURL:(NSURL *)targetURL
{
    return [[self alloc] initWithTargetURL:targetURL];
}

- (void)start
{
    _running = YES;
    _runTimer = [NSTimer timerWithTimeInterval:30
                                        target:self
                                      selector:@selector(checkReachability)
                                      userInfo:nil
                                       repeats:YES];
    [[NSRunLoop mainRunLoop]  addTimer:_runTimer forMode:NSDefaultRunLoopMode];
    [_runTimer fire];
}

- (void)stop
{
    if (_running)
    {
        [_runTimer invalidate];
        _runTimer = nil;
        
        _running = NO;
    }
}

- (void)checkReachability
{
    if (!_running)
        return;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.targetURL];
    [request setTimeoutInterval:10];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
    __weak typeof(self)weakObj = self;
    [[NSURLSession.sharedSession dataTaskWithRequest:request
                                   completionHandler:^(NSData * _Nullable data, 
                                                       NSURLResponse * _Nullable response,
                                                       NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^
                       {
            [weakObj handleResponse:response data:data error:error];
        });
    }] resume];
}

- (void)handleResponse:(NSURLResponse* _Nullable)response
                  data:(NSData* _Nullable)data
                 error:(NSError* _Nullable)error {
    if (!_running)
        return;
    
    if (error) {
        DLog(@"Connection error to %@: %@", self.targetURL, error);
    }
    
    BOOL noDataIsAvailable = !data && error && !response;
    if (noDataIsAvailable)
    {
        [self stop];
        
        if (self.delegate)
        {
            [self.delegate didLoseReachability:self];
        }
    }
}

@end
