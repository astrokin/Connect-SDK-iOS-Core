//
//  PlayTime.h
//  ConnectSDK
//
//  Created by MK on 2023/5/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PlayInfo : NSObject

@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval position;
@property (nonatomic, copy, nullable) NSString *url;

@end
NS_ASSUME_NONNULL_END
