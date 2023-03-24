//
//  CSNetworkHelper.h
//  ConnectSDK
//
//  Created by MK on 2023/3/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


typedef void (^CSNetworkHelperCallback)(NSURLResponse* _Nullable, NSData* _Nullable, NSError* _Nullable);

@interface CSNetworkHelper : NSObject

+ (void)sendAsynchronousRequest:(NSURLRequest*)request
              completionHandler:(CSNetworkHelperCallback)handler;

+ (void)sendAsynchronousRequest:(NSURLRequest*)request
                      queue:(NSOperationQueue * _Nullable)queue
completionHandler:(CSNetworkHelperCallback)handler;


@end

NS_ASSUME_NONNULL_END
