//
//  CSCollectionHelper.h
//  ConnectSDK
//
//  Created by MK on 2023/3/13.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CSCollectionHelper : NSObject

+ (__nullable id)getValue:(id)obj key:(NSString*)key;

+ (__nullable id)getValue:(id)obj keys:(NSArray< NSString*> *)keys;

@end

NS_ASSUME_NONNULL_END
