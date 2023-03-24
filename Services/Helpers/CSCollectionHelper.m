//
//  CSCollectionHelper.m
//  ConnectSDK
//
//  Created by MK on 2023/3/13.
//

#import "CSCollectionHelper.h"

@implementation CSCollectionHelper

+ (__nullable id)getValue:(id)obj key:(NSString*)key {
    if ([obj isKindOfClass:[NSDictionary class] ]) {
        return [(NSDictionary*)obj objectForKey:key];
    } else{
        return nil;
    }
}

+ (__nullable id)getValue:(id)obj keys:(NSArray< NSString*> *)keys {
    id value = obj;
    for (NSString *key in keys) {
        value = [self getValue:value key:key];
        if (value == nil) {
            break;
        }
    }
    return value;
}

@end
