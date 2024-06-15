#import "NewAndroidService_Private.h"

@interface NewAndroidService ()

@end

@implementation NewAndroidService


+ (NSDictionary *) discoveryParameters
{
    NSLog(@"NewAndroidService discoveryParameters");
    return @{
        @"serviceId" : kConnectSDKNewAndroidServiceId,
        @"zeroconf" : @{
                @"filter" : @"_androidtvremote2._tcp"
        }
    };
}

- (BOOL) isConnectable
{
    return YES;
}

- (void) connect
{
    self.connected = YES;
}

- (void) disconnect
{
    self.connected = NO;
}

//- (BOOL) connected
//{
//    return self.connected;
//}

@end
