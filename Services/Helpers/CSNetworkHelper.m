//
//  CSNetworkHelper.m
//  ConnectSDK
//
//  Created by MK on 2023/3/24.
//

#import "CSNetworkHelper.h"

@implementation CSNetworkHelper

+ (void)sendAsynchronousRequest:(NSURLRequest*)request
              completionHandler:(void (^)(NSURLResponse* _Nullable response, NSData* _Nullable data, NSError* _Nullable connectionError)) handler {
    [self sendAsynchronousRequest:request
                            queue:nil
                completionHandler:handler];
}


+ (void)sendAsynchronousRequest:(NSURLRequest*)request
                      queue:(NSOperationQueue * _Nullable)queue
              completionHandler:(CSNetworkHelperCallback)handler {
    NSOperationQueue *optQueue = queue ?: NSOperationQueue.mainQueue;
    
    [[NSURLSession.sharedSession dataTaskWithRequest:request
                                   completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSOperation *opt = [NSBlockOperation blockOperationWithBlock:^{
            handler(response,data, error);
        }];
        [optQueue addOperation:opt];
    }] resume];
}

@end
