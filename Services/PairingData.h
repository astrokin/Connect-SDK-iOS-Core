#import <Foundation/Foundation.h>
#import "Capabilities/Capability.h"

NS_ASSUME_NONNULL_BEGIN

@interface PairingData : NSObject

@property (nonatomic, copy) NSString *pairingKey;
@property (nonatomic, copy) SuccessBlock success;
@property (nonatomic, copy) FailureBlock failure;

- (instancetype)initWithPairingKey:(NSString *)pairingKey
                           success:(SuccessBlock)success
                           failure:(FailureBlock)failure;

@end


NS_ASSUME_NONNULL_END
