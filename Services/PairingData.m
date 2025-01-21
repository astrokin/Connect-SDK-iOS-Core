#import "PairingData.h"

@implementation PairingData

- (instancetype)initWithPairingKey:(NSString *)pairingKey
                           success:(SuccessBlock)success
                           failure:(FailureBlock)failure {
    self = [super init];
    if (self) {
        _pairingKey = [pairingKey copy];
        _success = [success copy];
        _failure = [failure copy];
    }
    return self;
}

@end
