//
//  MulticastDelegateProxy.m
//  SmartLinkTVFull
//
//  Created by Alexey Strokin on 12/08/2025.
//

#import "MulticastDelegateProxy.h"
#import <objc/runtime.h>

@interface MulticastDelegateProxy ()
@property (nonatomic, strong) NSHashTable *delegates;
@property (nonatomic, assign) Protocol *protocol;
@end

@implementation MulticastDelegateProxy

- (instancetype)initWithProtocol:(Protocol *)protocol {
    _protocol = protocol;
    _delegates = [NSHashTable weakObjectsHashTable];
    return self;
}

- (void)addDelegate:(id)delegate {
    if (delegate) { [self.delegates addObject:delegate]; }
}
- (void)removeDelegate:(id)delegate { if (delegate) [self.delegates removeObject:delegate]; }
- (void)removeAllDelegates { [self.delegates removeAllObjects]; }
- (NSArray *)allDelegates { return self.delegates.allObjects; }

#pragma mark - NSProxy plumbing

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    
    struct objc_method_description desc =
    protocol_getMethodDescription(self.protocol, sel, NO, YES);
    if (desc.name == NULL) {
        desc = protocol_getMethodDescription(self.protocol, sel, YES, YES);
    }
    if (desc.name != NULL) {
        return [NSMethodSignature signatureWithObjCTypes:desc.types];
    }
    for (id d in self.delegates) {
        if ([d respondsToSelector:sel]) {
            return [(NSObject *)d methodSignatureForSelector:sel];
        }
    }
    
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSArray *snapshot = self.delegates.allObjects;
    BOOL invoked = NO;
    for (id d in snapshot) {
        if ([d respondsToSelector:invocation.selector]) {
            [invocation invokeWithTarget:d];
            invoked = YES;
        }
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (protocol_getMethodDescription(self.protocol, aSelector, NO, YES).name ||
        protocol_getMethodDescription(self.protocol, aSelector, YES, YES).name) {
        return YES;
    }
    for (id d in self.delegates) {
        if ([d respondsToSelector:aSelector]) return YES;
    }
    return [super respondsToSelector:aSelector];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    if (aProtocol == self.protocol) return YES;
    for (id d in self.delegates) {
        if ([d conformsToProtocol:aProtocol]) return YES;
    }
    return [super conformsToProtocol:aProtocol];
}

@end
