//
//  MulticastDelegateProxy.h
//  SmartLinkTVFull
//
//  Created by Alexey Strokin on 12/08/2025.
//

#import <Foundation/Foundation.h>

@interface MulticastDelegateProxy : NSProxy

- (instancetype)initWithProtocol:(Protocol *)protocol;

- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;
- (void)removeAllDelegates;
- (NSArray *)allDelegates;

@end
