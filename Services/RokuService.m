//
//  RokuService.m
//  ConnectSDK
//
//  Created by Jeremy White on 2/14/14.
//  Copyright (c) 2014 LG Electronics.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "RokuService_Private.h"
#import "ConnectError.h"
#import "CTXMLReader.h"
#import "ConnectUtil.h"
#import "DeviceServiceReachability.h"
#import "DiscoveryManager.h"
#import "CSNetworkHelper.h"
#import "NSObject+FeatureNotSupported_Private.h"
#import "CSCollectionHelper.h"
#import <Foundation/Foundation.h>
#import "ConnectSDKLog.h"

static NSTimeInterval _parseTime(NSString *text) {
    if (text == nil || ![text isKindOfClass:NSString.class] ||  text.length == 0) {
        return 0;
    }
    NSArray <NSString *> *list = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *first= list.firstObject;
    NSTimeInterval value = 0;
    if (first.length > 0) {
        value = first.doubleValue;
    }
    if (list.count > 1) {
        NSString *unit= list[1];
        if ([unit isEqualToString:@"ms"]) {
            value /= 1000;
        }
    }
    value = (100 * value) / 100;
    return value;
}

@interface RokuPlayState ()
@property (nonatomic,assign) NSInteger checkCount;
@end

@implementation RokuPlayState {
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _playState = MediaControlPlayStateUnknown;
        _duration = 0;
        _position = 0;
    }
    return self;
}

+ (instancetype)stateFromPlayerDict:(NSDictionary *)dict {
    if(![dict isKindOfClass:[NSDictionary class]]) {
        return  nil;
    }
    RokuPlayState *state = [[RokuPlayState alloc] init];
    
    state.duration = _parseTime([CSCollectionHelper getValue:dict keys:@[@"duration", @"text"]]);
    state.position = _parseTime([CSCollectionHelper getValue:dict keys:@[@"position", @"text"]]);

    NSString *stateText = [CSCollectionHelper getValue:dict key:@"state"];
    if ([stateText isEqualToString:@"play"]) {
        state.playState = MediaControlPlayStatePlaying;
    } else if ([stateText isEqualToString:@"pause"]) {
        state.playState = MediaControlPlayStatePaused;
    }  else if ([stateText isEqualToString:@"buffer"]) {
        state.playState = MediaControlPlayStateBuffering;
    }  else if ([stateText isEqualToString:@"startup"]) {
        state.playState = MediaControlPlayStateIdle;
    }  else if ([stateText isEqualToString:@"close"]) {
        state.playState = MediaControlPlayStateIdle;
    } else {
        DLog(@"get unknown state %@", stateText ?: @"null")
    }

    return state;
}

- (NSTimeInterval)timeLeft {
    return _duration - _position;
}

@end


@interface RokuService () <ServiceCommandDelegate, DeviceServiceReachabilityDelegate>
{
    DIALService *_dialService;
    DeviceServiceReachability *_serviceReachability;
}
@end

static NSMutableArray *registeredApps = nil;

@implementation RokuService

+ (void) initialize
{
    registeredApps = [NSMutableArray arrayWithArray:@[
            @"YouTube",
            @"Netflix",
            @"Amazon"
    ]];
}

+ (NSDictionary *)discoveryParameters
{
    return @{
            @"serviceId" : kConnectSDKRokuServiceId,
            @"ssdp" : @{
                    @"filter" : @"roku:ecp"
            }
    };
}

- (void) updateCapabilities
{
    NSArray *capabilities = @[
        kLauncherAppList,
        kLauncherApp,
        kLauncherAppParams,
        kLauncherAppStore,
        kLauncherAppStoreParams,
        kLauncherAppClose,

        kMediaPlayerDisplayImage,
        kMediaPlayerPlayVideo,
        kMediaPlayerPlayAudio,
        kMediaPlayerClose,
        kMediaPlayerMetaDataTitle,

        kMediaControlPlay,
        kMediaControlPause,
        kMediaControlRewind,
        kMediaControlFastForward,

        kTextInputControlSendText,
        kTextInputControlSendEnter,
        kTextInputControlSendDelete
    ];

    capabilities = [capabilities arrayByAddingObjectsFromArray:kKeyControlCapabilities];

    [self setCapabilities:capabilities];
}

+ (void) registerApp:(NSString *)appId
{
    if (![registeredApps containsObject:appId])
        [registeredApps addObject:appId];
}

- (void) probeForApps
{
    [registeredApps enumerateObjectsUsingBlock:^(NSString *appName, NSUInteger idx, BOOL *stop)
    {
        [self hasApp:appName success:^(AppInfo *appInfo)
        {
            NSString *capability = [NSString stringWithFormat:@"Launcher.%@", appName];
            NSString *capabilityParams = [NSString stringWithFormat:@"Launcher.%@.Params", appName];

            [self addCapabilities:@[capability, capabilityParams]];
        } failure:nil];
    }];
}

- (BOOL) isConnectable
{
    return YES;
}

- (void) connect
{
    NSString *targetPath = [NSString stringWithFormat:@"http://%@:%@/", self.serviceDescription.address, @(self.serviceDescription.port)];
    NSURL *targetURL = [NSURL URLWithString:targetPath];

    _serviceReachability = [DeviceServiceReachability reachabilityWithTargetURL:targetURL];
    _serviceReachability.delegate = self;
    [_serviceReachability start];

    self.connected = YES;

    if (self.delegate && [self.delegate respondsToSelector:@selector(deviceServiceConnectionSuccess:)])
        dispatch_on_main(^{ [self.delegate deviceServiceConnectionSuccess:self]; });
}

- (void) disconnect
{
    self.connected = NO;

    [_serviceReachability stop];

    if (self.delegate && [self.delegate respondsToSelector:@selector(deviceService:disconnectedWithError:)])
        dispatch_on_main(^{ [self.delegate deviceService:self disconnectedWithError:nil]; });
}

- (void) didLoseReachability:(DeviceServiceReachability *)reachability
{
    if (self.connected)
        [self disconnect];
    else
        [_serviceReachability stop];
}

- (void)setServiceDescription:(ServiceDescription *)serviceDescription
{
    [super setServiceDescription:serviceDescription];

    self.serviceDescription.port = 8060;
    NSString *commandPath = [NSString stringWithFormat:@"http://%@:%@", self.serviceDescription.address, @(self.serviceDescription.port)];
    self.serviceDescription.commandURL = [NSURL URLWithString:commandPath];

    [self probeForApps];
}

- (DIALService *) dialService
{
    if (!_dialService)
    {
        ConnectableDevice *device = [[DiscoveryManager sharedManager].allDevices objectForKey:self.serviceDescription.address];
        __block DIALService *foundService;

        [device.services enumerateObjectsUsingBlock:^(DeviceService *service, NSUInteger idx, BOOL *stop)
        {
            if ([service isKindOfClass:[DIALService class]])
            {
                foundService = (DIALService *) service;
                *stop = YES;
            }
        }];

        if (foundService)
            _dialService = foundService;
    }

    return _dialService;
}

#pragma mark - Getters & Setters

/// Returns the set delegate property value or self.
- (id<ServiceCommandDelegate>)serviceCommandDelegate {
    return _serviceCommandDelegate ?: self;
}

#pragma mark - ServiceCommandDelegate

- (int) sendCommand:(ServiceCommand *)command withPayload:(NSDictionary *)payload toURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
    [request setTimeoutInterval:6];
    [request addValue:@"text/plain;charset=\"utf-8\"" forHTTPHeaderField:@"Content-Type"];

    if (payload || [command.HTTPMethod isEqualToString:@"POST"])
    {
        [request setHTTPMethod:@"POST"];

        if (payload)
        {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
            [request addValue:[NSString stringWithFormat:@"%i", (unsigned int) [jsonData length]] forHTTPHeaderField:@"Content-Length"];
            [request setHTTPBody:jsonData];
        }
    } else
    {
        [request setHTTPMethod:@"GET"];
        [request addValue:@"0" forHTTPHeaderField:@"Content-Length"];
    }

    [CSNetworkHelper sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
    {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if (connectionError)
        {
            if (command.callbackError)
                dispatch_on_main(^{ command.callbackError(connectionError); });
        } else
        {
            if ([httpResponse statusCode] < 200 || [httpResponse statusCode] >= 300)
            {
                NSError *error = [ConnectError generateErrorWithCode:ConnectStatusCodeTvError andDetails:nil];
                
                if (command.callbackError)
                    command.callbackError(error);
                
                return;
            }
            
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            if (command.callbackComplete)
                dispatch_on_main(^{ command.callbackComplete(dataString); });
        }
    }];

    // TODO: need to implement callIds in here
    return 0;
}

#pragma mark - Launcher

- (id <Launcher>)launcher
{
    return self;
}

- (CapabilityPriorityLevel)launcherPriority
{
    return CapabilityPriorityLevelHigh;
}

- (void)launchApp:(NSString *)appId success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    if (!appId)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:@"You must provide an appId."]);
        return;
    }

    AppInfo *appInfo = [AppInfo appInfoForId:appId];

    [self launchAppWithInfo:appInfo params:nil success:success failure:failure];
}

- (void)launchAppWithInfo:(AppInfo *)appInfo success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    [self launchAppWithInfo:appInfo params:nil success:success failure:failure];
}

- (void)launchAppWithInfo:(AppInfo *)appInfo params:(NSDictionary *)params success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    if (!appInfo || !appInfo.id)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:@"You must provide a valid AppInfo object."]);
        return;
    }

    NSURL *targetURL = [self.serviceDescription.commandURL URLByAppendingPathComponent:@"launch"];
    targetURL = [targetURL URLByAppendingPathComponent:appInfo.id];
    
    if (params)
    {
        __block NSString *queryParams = @"";
        __block int count = 0;
        
        [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
            NSString *prefix = (count == 0) ? @"?" : @"&";
            
            NSString *urlSafeKey = [ConnectUtil urlEncode:key];
            NSString *urlSafeValue = [ConnectUtil urlEncode:value];
            
            NSString *appendString = [NSString stringWithFormat:@"%@%@=%@", prefix, urlSafeKey, urlSafeValue];
            queryParams = [queryParams stringByAppendingString:appendString];
            
            count++;
        }];
        
        NSString *targetPath = [NSString stringWithFormat:@"%@%@", targetURL.absoluteString, queryParams];
        targetURL = [NSURL URLWithString:targetPath];
    }

    ServiceCommand *command = [ServiceCommand commandWithDelegate:self target:targetURL payload:nil];
    command.callbackComplete = ^(id responseObject)
    {
        LaunchSession *launchSession = [LaunchSession launchSessionForAppId:appInfo.id];
        launchSession.name = appInfo.name;
        launchSession.sessionType = LaunchSessionTypeApp;
        launchSession.service = self;

        if (success)
            success(launchSession);
    };
    command.callbackError = failure;
    [command send];
}

- (void)launchYouTube:(NSString *)contentId success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    [self launchYouTube:contentId startTime:0.0 success:success failure:failure];
}

- (void) launchYouTube:(NSString *)contentId startTime:(float)startTime success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    if (self.dialService)
        [self.dialService.launcher launchYouTube:contentId startTime:startTime success:success failure:failure];
    else
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeNotSupported andDetails:@"Cannot reach DIAL service for launching with provided start time"]);
    }
}

- (void) launchAppStore:(NSString *)appId success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    AppInfo *appInfo = [AppInfo appInfoForId:@"11"];
    appInfo.name = @"Channel Store";

    NSDictionary *params;

    if (appId && appId.length > 0)
        params = @{ @"contentId" : appId };

    [self launchAppWithInfo:appInfo params:params success:success failure:failure];
}

- (void)launchBrowser:(NSURL *)target success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    [self sendNotSupportedFailure:failure];
}

- (void)launchHulu:(NSString *)contentId success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    [self sendNotSupportedFailure:failure];
}

- (void)launchNetflix:(NSString *)contentId success:(AppLaunchSuccessBlock)success failure:(FailureBlock)failure
{
    [self getAppListWithSuccess:^(NSArray *appList)
    {
        __block AppInfo *foundAppInfo;

        [appList enumerateObjectsUsingBlock:^(AppInfo *appInfo, NSUInteger idx, BOOL *stop)
        {
            if ([appInfo.name isEqualToString:@"Netflix"])
            {
                foundAppInfo = appInfo;
                *stop = YES;
            }
        }];

        if (foundAppInfo)
        {
            NSMutableDictionary *params = [NSMutableDictionary new];
            params[@"mediaType"] = @"movie";
            if (contentId && contentId.length > 0) params[@"contentId"] = contentId;

            [self launchAppWithInfo:foundAppInfo params:params success:success failure:failure];
        } else
        {
            if (failure)
                failure([ConnectError generateErrorWithCode:ConnectStatusCodeError andDetails:@"Netflix app could not be found on TV"]);
        }
    } failure:failure];
}

- (void)closeApp:(LaunchSession *)launchSession success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self.keyControl homeWithSuccess:success failure:failure];
}

- (void)getAppListWithSuccess:(AppListSuccessBlock)success failure:(FailureBlock)failure
{
    NSURL *targetURL = [self.serviceDescription.commandURL URLByAppendingPathComponent:@"query"];
    targetURL = [targetURL URLByAppendingPathComponent:@"apps"];

    ServiceCommand *command = [ServiceCommand commandWithDelegate:self.serviceCommandDelegate target:targetURL payload:nil];
    command.HTTPMethod = @"GET";
    command.callbackComplete = ^(NSString *responseObject)
    {
        NSError *xmlError;
        NSDictionary *appListDictionary = [CTXMLReader dictionaryForXMLString:responseObject error:&xmlError];

        if (appListDictionary) {
            NSArray *apps;
            id appsObject = [appListDictionary valueForKeyPath:@"apps.app"];
            if ([appsObject isKindOfClass:[NSDictionary class]]) {
                apps = @[appsObject];
            } else if ([appsObject isKindOfClass:[NSArray class]]) {
                apps = appsObject;
            }

            NSMutableArray *appList = [NSMutableArray new];

            [apps enumerateObjectsUsingBlock:^(NSDictionary *appInfoDictionary, NSUInteger idx, BOOL *stop)
            {
                AppInfo *appInfo = [self appInfoFromDictionary:appInfoDictionary];
                [appList addObject:appInfo];
            }];

            if (success)
                success([NSArray arrayWithArray:appList]);
        } else {
            if (failure) {
                NSString *details = [NSString stringWithFormat:
                    @"Couldn't parse apps XML (%@)", xmlError.localizedDescription];
                failure([ConnectError generateErrorWithCode:ConnectStatusCodeTvError
                                                 andDetails:details]);
            }
        }
    };
    command.callbackError = failure;
    [command send];
}

- (void)getAppState:(LaunchSession *)launchSession success:(AppStateSuccessBlock)success failure:(FailureBlock)failure
{
    [self sendNotSupportedFailure:failure];
}

- (ServiceSubscription *)subscribeAppState:(LaunchSession *)launchSession success:(AppStateSuccessBlock)success failure:(FailureBlock)failure
{
    return [self sendNotSupportedFailure:failure];
}

- (void)getRunningAppWithSuccess:(AppInfoSuccessBlock)success failure:(FailureBlock)failure
{
    [self sendNotSupportedFailure:failure];
}

- (ServiceSubscription *)subscribeRunningAppWithSuccess:(AppInfoSuccessBlock)success failure:(FailureBlock)failure
{
    return [self sendNotSupportedFailure:failure];
}

#pragma mark - MediaPlayer

- (id <MediaPlayer>)mediaPlayer
{
    return self;
}

- (CapabilityPriorityLevel)mediaPlayerPriority
{
    return CapabilityPriorityLevelHigh;
}

- (void)displayImage:(NSURL *)imageURL iconURL:(NSURL *)iconURL title:(NSString *)title description:(NSString *)description mimeType:(NSString *)mimeType success:(MediaPlayerDisplaySuccessBlock)success failure:(FailureBlock)failure
{
    MediaInfo *mediaInfo = [[MediaInfo alloc] initWithURL:imageURL mimeType:mimeType];
    mediaInfo.title = title;
    mediaInfo.description = description;
    ImageInfo *imageInfo = [[ImageInfo alloc] initWithURL:iconURL type:ImageTypeThumb];
    [mediaInfo addImage:imageInfo];
    
    [self displayImageWithMediaInfo:mediaInfo success:^(MediaLaunchObject *mediaLanchObject) {
        success(mediaLanchObject.session,mediaLanchObject.mediaControl);
    } failure:failure];
}

- (void) displayImage:(MediaInfo *)mediaInfo
              success:(MediaPlayerDisplaySuccessBlock)success
              failure:(FailureBlock)failure
{
    NSURL *iconURL;
    if(mediaInfo.images){
        ImageInfo *imageInfo = [mediaInfo.images firstObject];
        iconURL = imageInfo.url;
    }
    
    [self displayImage:mediaInfo.url iconURL:iconURL title:mediaInfo.title description:mediaInfo.description mimeType:mediaInfo.mimeType success:success failure:failure];
}

- (void) displayImageWithMediaInfo:(MediaInfo *)mediaInfo success:(MediaPlayerSuccessBlock)success failure:(FailureBlock)failure
{
    NSURL *imageURL = mediaInfo.url;
    if (!imageURL)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:@"You need to provide a video URL"]);
        
        return;
    }
    
    // t = p (photo)
    NSString *applicationPath = [NSString stringWithFormat:@"15985?t=p&h=a&u=%@&tr=crossfade",
                                 [ConnectUtil urlEncode:imageURL.absoluteString] // content path
                                 ];
    
    NSString *commandPath = [NSString pathWithComponents:@[
                                                           self.serviceDescription.commandURL.absoluteString,
                                                           @"input",
                                                           applicationPath
                                                           ]];
    
    NSURL *targetURL = [NSURL URLWithString:commandPath];
    
    ServiceCommand *command = [ServiceCommand commandWithDelegate:self.serviceCommandDelegate target:targetURL payload:nil];
    command.HTTPMethod = @"POST";
    command.callbackComplete = ^(id responseObject)
    {
        LaunchSession *launchSession = [LaunchSession launchSessionForAppId:@"15985"];
        launchSession.name = @"simplevideoplayer";
        launchSession.sessionType = LaunchSessionTypeMedia;
        launchSession.service = self;
        
        MediaLaunchObject *launchObject = [[MediaLaunchObject alloc] initWithLaunchSession:launchSession andMediaControl:self.mediaControl];
        if(success){
            success(launchObject);
        }
    };
    command.callbackError = failure;
    [command send];
}

- (void) playMedia:(NSURL *)mediaURL iconURL:(NSURL *)iconURL title:(NSString *)title description:(NSString *)description mimeType:(NSString *)mimeType shouldLoop:(BOOL)shouldLoop success:(MediaPlayerDisplaySuccessBlock)success failure:(FailureBlock)failure
{
    MediaInfo *mediaInfo = [[MediaInfo alloc] initWithURL:mediaURL mimeType:mimeType];
    mediaInfo.title = title;
    mediaInfo.description = description;
    ImageInfo *imageInfo = [[ImageInfo alloc] initWithURL:iconURL type:ImageTypeThumb];
    [mediaInfo addImage:imageInfo];
    
    [self playMediaWithMediaInfo:mediaInfo shouldLoop:shouldLoop success:^(MediaLaunchObject *mediaLanchObject) {
        success(mediaLanchObject.session,mediaLanchObject.mediaControl);
    } failure:failure];
}

- (void) playMedia:(MediaInfo *)mediaInfo shouldLoop:(BOOL)shouldLoop success:(MediaPlayerDisplaySuccessBlock)success failure:(FailureBlock)failure
{
    NSURL *iconURL;
    if(mediaInfo.images){
        ImageInfo *imageInfo = [mediaInfo.images firstObject];
        iconURL = imageInfo.url;
    }
    [self playMedia:mediaInfo.url iconURL:iconURL title:mediaInfo.title description:mediaInfo.description mimeType:mediaInfo.mimeType shouldLoop:shouldLoop success:success failure:failure];
}

- (void) playMediaWithMediaInfo:(MediaInfo *)mediaInfo shouldLoop:(BOOL)shouldLoop success:(MediaPlayerSuccessBlock)success failure:(FailureBlock)failure
{
    NSURL *iconURL;
    if(mediaInfo.images){
        ImageInfo *imageInfo = [mediaInfo.images firstObject];
        iconURL = imageInfo.url;
    }
    NSURL *mediaURL = mediaInfo.url;
    NSString *mimeType = mediaInfo.mimeType;
    NSString *title = mediaInfo.title;
    NSString *description = mediaInfo.description;
    if (!mediaURL)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:@"You need to provide a media URL"]);
        
        return;
    }
    
    NSString *mediaType = [[mimeType componentsSeparatedByString:@"/"] lastObject];
    BOOL isVideo = [[mimeType substringToIndex:1] isEqualToString:@"v"];
    
    NSString *applicationPath;
    
    if (isVideo)
    {
        // t = v (video)
        BOOL isStream = [[mediaURL pathExtension] hasSuffix:@"m3u8"];

        applicationPath = [NSString stringWithFormat:@"15985?t=v&h=a&u=%@&k=a&videoName=%@&videoFormat=%@",
                           [ConnectUtil urlEncode:mediaURL.absoluteString], // content path
                           title ? [ConnectUtil urlEncode:title] : @"(null)", // video name
                           isStream ? @"(null)" : ensureString(mediaType) // video format
                           ];
    } else {
        // t = a (audio)
        applicationPath = [NSString stringWithFormat:@"15985?t=a&h=a&u=%@&k=a&songname=%@&artistname=%@&songformat=%@&albumarturl=%@",
                           [ConnectUtil urlEncode:mediaURL.absoluteString], // content path
                           title ? [ConnectUtil urlEncode:title] : @"(null)", // song name
                           description ? [ConnectUtil urlEncode:description] : @"(null)", // artist name
                           ensureString(mediaType), // audio format
                           iconURL ? [ConnectUtil urlEncode:iconURL.absoluteString] : @"(null)"
                           ];
    }
    
    NSString *commandPath = [NSString pathWithComponents:@[
                                                           self.serviceDescription.commandURL.absoluteString,
                                                           @"input",
                                                           applicationPath
                                                           ]];
    
    NSURL *targetURL = [NSURL URLWithString:commandPath];
    
    ServiceCommand *command = [ServiceCommand commandWithDelegate:self.serviceCommandDelegate target:targetURL payload:nil];
    command.HTTPMethod = @"POST";
    command.callbackComplete = ^(id responseObject)
    {
        LaunchSession *launchSession = [LaunchSession launchSessionForAppId:@"15985"];
        launchSession.name = @"simplevideoplayer";
        launchSession.sessionType = LaunchSessionTypeMedia;
        launchSession.service = self;
         MediaLaunchObject *launchObject = [[MediaLaunchObject alloc] initWithLaunchSession:launchSession andMediaControl:self.mediaControl];
         if(success){
            success(launchObject);
         }
    };
    command.callbackError = failure;
    [command send];
}

- (void)closeMedia:(LaunchSession *)launchSession success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self.keyControl homeWithSuccess:success failure:failure];
}

#pragma mark - MediaControl

- (id <MediaControl>)mediaControl
{
    return self;
}

- (CapabilityPriorityLevel)mediaControlPriority
{
    return CapabilityPriorityLevelHigh;
}

- (void)playWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodePlay success:success failure:failure];
}

- (void)pauseWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    // Roku does not have pause, it only has play/pause
    [self sendKeyCode:RokuKeyCodePlay success:success failure:failure];
}

- (void)stopWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendNotSupportedFailure:failure];
}

- (void)rewindWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeRewind success:success failure:failure];
}

- (void)fastForwardWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeFastForward success:success failure:failure];
}

- (void)seek:(NSTimeInterval)position success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSString *query = [NSString stringWithFormat:@"input?cmd=seek&seekto=%@", @(position)];
    NSString *commandPath = [NSString pathWithComponents:@[self.serviceDescription.commandURL.absoluteString,
                                                           query]];
    NSURL *targetURL = [NSURL URLWithString:commandPath];
    ServiceCommand *command = [ServiceCommand commandWithDelegate:self.serviceCommandDelegate target:targetURL payload:nil];
    command.HTTPMethod = @"POST";
    command.callbackComplete = ^(id responseObject) {
        NSError *xmlError;
        NSDictionary *dict = [CTXMLReader dictionaryForXMLString:responseObject error:&xmlError];
        
        if (dict) {
            if (success)
                success(nil);
        } else {
            if (failure) {
                NSString *details = [NSString stringWithFormat:
                                     @"Couldn't parse apps XML (%@)", xmlError.localizedDescription];
                failure([ConnectError generateErrorWithCode:ConnectStatusCodeTvError
                                                 andDetails:details]);
            }
        }
    };
    command.callbackError = failure;
    [command send];
}

- (void)getPlayStateWithSuccess:(MediaPlayStateSuccessBlock)success failure:(FailureBlock)failure
{
    [self sendNotSupportedFailure:failure];
}

- (ServiceSubscription *)subscribePlayStateWithSuccess:(MediaPlayStateSuccessBlock)success failure:(FailureBlock)failure
{
    return [self sendNotSupportedFailure:failure];
}

- (void)getDurationWithSuccess:(MediaPositionSuccessBlock)success
                       failure:(FailureBlock)failure {
    [self sendNotSupportedFailure:failure];
}

- (void)getPositionWithSuccess:(MediaPositionSuccessBlock)success failure:(FailureBlock)failure
{
    NSURL *targetURL = [self.serviceDescription.commandURL URLByAppendingPathComponent:@"query"];
    targetURL = [targetURL URLByAppendingPathComponent:@"media-player"];
    ServiceCommand *command = [ServiceCommand commandWithDelegate:self.serviceCommandDelegate target:targetURL payload:nil];
    command.HTTPMethod = @"GET";
    __weak typeof(self)weakObj = self;
    command.callbackComplete = ^(id responseObject)
    {
        NSError *xmlError;
        NSDictionary *dict = [CTXMLReader dictionaryForXMLString:responseObject error:&xmlError];
        
        if (dict) {
            NSDictionary *player = [CSCollectionHelper getValue:dict key:@"player"];
            NSString *errText = [[CSCollectionHelper getValue:player key:@"error"] description];
            if ([errText isEqualToString:@"false"]) {
                RokuPlayState *state = [RokuPlayState stateFromPlayerDict:player];
                weakObj.playState = state;
                if (success) {
                    success(state.position);
                }
            } else if (failure) {
                failure([ConnectError generateErrorWithCode:ConnectStatusCodeTvError
                                                 andDetails:errText ?: @"unknown"]);
            }
        } else {
            if (failure) {
                NSString *details = [NSString stringWithFormat:
                                     @"Couldn't parse apps XML (%@)", xmlError.localizedDescription];
                failure([ConnectError generateErrorWithCode:ConnectStatusCodeTvError
                                                 andDetails:details]);
            }
        }
    };
    command.callbackError = failure;
    [command send];
}

- (void)getMediaMetaDataWithSuccess:(SuccessBlock)success
                            failure:(FailureBlock)failure {
    [self sendNotSupportedFailure:failure];
}

- (ServiceSubscription *)subscribeMediaInfoWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    return [self sendNotSupportedFailure:failure];
}

#pragma mark - Key Control

- (id <KeyControl>) keyControl
{
    return self;
}

- (CapabilityPriorityLevel) keyControlPriority
{
    return CapabilityPriorityLevelHigh;
}

- (void)upWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeUp success:success failure:failure];
}

- (void)downWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeDown success:success failure:failure];
}

- (void)leftWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeLeft success:success failure:failure];
}

- (void)rightWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeRight success:success failure:failure];
}

- (void)homeWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeHome success:success failure:failure];
}

- (void)backWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeBack success:success failure:failure];
}

- (void)okWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeSelect success:success failure:failure];
}

- (void)sendKeyCode:(RokuKeyCode)keyCode success:(SuccessBlock)success failure:(FailureBlock)failure
{
    if (keyCode > kRokuKeyCodes.count)
    {
        if (failure)
            failure([ConnectError generateErrorWithCode:ConnectStatusCodeArgumentError andDetails:nil]);
        return;
    }

    NSString *keyCodeString = kRokuKeyCodes[keyCode];

    [self sendKeyPress:keyCodeString success:success failure:failure];
}

#pragma mark - Text Input Control

- (id <TextInputControl>) textInputControl
{
    return self;
}

- (CapabilityPriorityLevel) textInputControlPriority
{
    return CapabilityPriorityLevelNormal;
}

- (void) sendText:(NSString *)input success:(SuccessBlock)success failure:(FailureBlock)failure
{
    // TODO: optimize this with queueing similiar to webOS and Netcast services
    NSMutableArray *stringToSend = [NSMutableArray new];

    [input enumerateSubstringsInRange:NSMakeRange(0, input.length) options:(NSStringEnumerationByComposedCharacterSequences) usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
    {
        [stringToSend addObject:substring];
    }];

    [stringToSend enumerateObjectsUsingBlock:^(NSString *charToSend, NSUInteger idx, BOOL *stop)
    {

        NSString *codeToSend = [NSString stringWithFormat:@"%@%@", kRokuKeyCodes[RokuKeyCodeLiteral], [ConnectUtil urlEncode:charToSend]];

        [self sendKeyPress:codeToSend success:success failure:failure];
    }];
}

- (void)sendEnterWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeEnter success:success failure:failure];
}

- (void)sendDeleteWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self sendKeyCode:RokuKeyCodeBackspace success:success failure:failure];
}

- (ServiceSubscription *) subscribeTextInputStatusWithSuccess:(TextInputStatusInfoSuccessBlock)success failure:(FailureBlock)failure
{
    return [self sendNotSupportedFailure:failure];
}

#pragma mark - Helper methods

- (void) sendKeyPress:(NSString *)keyCode success:(SuccessBlock)success failure:(FailureBlock)failure
{
    NSURL *targetURL = [self.serviceDescription.commandURL URLByAppendingPathComponent:@"keypress"];
    targetURL = [NSURL URLWithString:[targetURL.absoluteString stringByAppendingPathComponent:keyCode]];

    ServiceCommand *command = [ServiceCommand commandWithDelegate:self target:targetURL payload:nil];
    command.callbackComplete = success;
    command.callbackError = failure;
    [command send];
}

- (AppInfo *)appInfoFromDictionary:(NSDictionary *)appDictionary
{
    NSString *id = [appDictionary objectForKey:@"id"];
    NSString *name = [appDictionary objectForKey:@"text"];

    AppInfo *appInfo = [AppInfo appInfoForId:id];
    appInfo.name = name;
    appInfo.rawData = [appDictionary copy];

    return appInfo;
}

- (void) hasApp:(NSString *)appName success:(SuccessBlock)success failure:(FailureBlock)failure
{
    [self.launcher getAppListWithSuccess:^(NSArray *appList)
    {
        if (appList)
        {
            __block AppInfo *foundAppInfo;

            [appList enumerateObjectsUsingBlock:^(AppInfo *appInfo, NSUInteger idx, BOOL *stop)
            {
                if ([appInfo.name isEqualToString:appName])
                {
                    foundAppInfo = appInfo;
                    *stop = YES;
                }
            }];

            if (foundAppInfo)
            {
                if (success)
                    success(foundAppInfo);
            } else
            {
                if (failure)
                    failure([ConnectError generateErrorWithCode:ConnectStatusCodeError andDetails:@"Could not find this app on the TV"]);
            }
        } else
        {
            if (failure)
                failure([ConnectError generateErrorWithCode:ConnectStatusCodeTvError andDetails:@"Could not find any apps on the TV."]);
        }
    } failure:failure];
}

- (void)setPlayState:(RokuPlayState *)playState {
    if (_playState == nil) {
        _playState = playState;
        return;
    }
    
    if (_playState == playState) {
        return;
    }
    
    if (playState == nil
        || playState.playState != MediaControlPlayStatePlaying) {
        _playState = playState;
        _playState.checkCount = 0;
        return;
    }
    
    NSTimeInterval lastLeft = [_playState timeLeft];
    NSInteger checkCount = _playState.checkCount;
    if (lastLeft < 2) {
        NSTimeInterval left = [playState timeLeft];
        if (abs(left-lastLeft) < 0.01) {
            checkCount++;
            if (checkCount > 3) {
                playState.playState = MediaControlPlayStateFinished;
            }
        } else {
            checkCount = 0;

        }
    } else {
        checkCount = 0;
    }
    playState.checkCount = playState.playState == MediaControlPlayStatePlaying ? checkCount : 0;
    _playState = playState;
}

@end

