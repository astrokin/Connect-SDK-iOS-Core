//
//  WebOSTVServiceMouse.h
//  Connect SDK
//
//  Created by Jeremy White on 1/3/14.
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

#import <Foundation/Foundation.h>
#import "Capability.h"
#import "LGKeyCodeDef.h"


typedef NS_ENUM(NSInteger, WebOSTVMouseButton) {
    WebOSTVMouseButtonHome = 1000,
    WebOSTVMouseButtonBack = 1001,
    WebOSTVMouseButtonUp = 1002,
    WebOSTVMouseButtonDown = 1003,
    WebOSTVMouseButtonLeft = 1004,
    WebOSTVMouseButtonRight = 1005,   /// some possible options from other source
    WebOSTVMouseButtonEnter = 1006,   ///WebOSTVMouseButtonRed = 1006,
    WebOSTVMouseButtonMenu = 1007,    ///WebOSTVMouseButtonGreen = 1007,
    WebOSTVMouseButtonInfo = 1008,    ///WebOSTVMouseButtonYellow = 1008,
    WebOSTVMouseButtonExit = 1009,    ///WebOSTVMouseButtonBlue = 1009,
    WebOSTVMouseButton0 = 1010,       ///WebOSTVMouseButtonInfo = 1010,
    WebOSTVMouseButton1 = 1011,
    WebOSTVMouseButton2 = 1012,
    WebOSTVMouseButton3 = 1013,
    WebOSTVMouseButton4 = 1014,
    WebOSTVMouseButton5 = 1015,
    WebOSTVMouseButton6 = 1016,
    WebOSTVMouseButton7 = 1017,
    WebOSTVMouseButton8 = 1018,
    WebOSTVMouseButton9 = 1019,       /// some possible options from other source
    WebOSTVMouseButtonRed = 1020,     ////WebOSTVMouseButtonNumber0 = 1020,
    WebOSTVMouseButtonGreen = 1021,   ///WebOSTVMouseButtonGuide = 1021,
    WebOSTVMouseButtonBlue = 1022,    ///WebOSTVMouseButtonDash = 1022,
    WebOSTVMouseButtonYellow = 1023,  ///WebOSTVMouseButtonMenu = 1023,
                                      ///WebOSTVMouseButtonExit = 1024
};

///yet another possible options from other source
/**
 WebOSTVMouseButtonPower = 1001,
 WebOSTVMouseButtonUp = 1002,
 WebOSTVMouseButtonDown = 1003,
 WebOSTVMouseButtonRight = 1004,
 WebOSTVMouseButtonLeft = 1005,
 WebOSTVMouseButtonMenu = 1006,
 WebOSTVMouseButtonHome = 1007,
 WebOSTVMouseButtonBack = 1008,
 WebOSTVMouseButtonExit = 1009,
 WebOSTVMouseButtonOk = 1010,
 WebOSTVMouseButtonVolumeUp = 1011,
 WebOSTVMouseButtonVolumeDown = 1012,
 WebOSTVMouseButtonChannelUp = 1013,
 WebOSTVMouseButtonChannelDown = 1014,
 WebOSTVMouseButtonSource = 1015,
 WebOSTVMouseButtonZero = 1016,
 WebOSTVMouseButtonOne = 1017,
 WebOSTVMouseButtonTwo = 1018,
 WebOSTVMouseButtonThree = 1019,
 WebOSTVMouseButtonFour = 1020,
 WebOSTVMouseButtonFive = 1021,
 WebOSTVMouseButtonSix = 1022,
 WebOSTVMouseButtonSeven = 1023,
 WebOSTVMouseButtonEight = 1024,
 WebOSTVMouseButtonNine = 1025,
 WebOSTVMouseButtonMute = 1026,
 WebOSTVMouseButtonPlay = 1027,
 WebOSTVMouseButtonPause = 1028,
 WebOSTVMouseButtonNext = 1029,
 WebOSTVMouseButtonPrev = 1030
 */

///yet another possible options from other source
/**
 WebOSTVMouseButtonEnter = 1006,
 WebOSTVMouseButtonMenu = 1007,
 WebOSTVMouseButtonInfo = 1008,
 WebOSTVMouseButtonExit = 1009,
 WebOSTVMouseButtonRed = 1010,
 WebOSTVMouseButtonGreen = 1011,
 WebOSTVMouseButtonYellow = 1012,
 WebOSTVMouseButtonBlue = 1013,
 WebOSTVMouseButtonList = 1014,
 WebOSTVMouseButtonAD = 1015,
 WebOSTVMouseButton0 = 1016,
 WebOSTVMouseButton1 = 1017,
 WebOSTVMouseButton2 = 1018,
 WebOSTVMouseButton3 = 1019,
 WebOSTVMouseButton4 = 1020,
 WebOSTVMouseButton5 = 1021,
 WebOSTVMouseButton6 = 1022,
 WebOSTVMouseButton7 = 1023,
 WebOSTVMouseButton8 = 1024,
 WebOSTVMouseButton9 = 1026,
 WebOSTVMouseButtonSearch = 1027,
 WebOSTVMouseButtonScreenRemote=1028,
 WebOSTVMouseButtonMute = 1029
 */

@interface WebOSTVServiceMouse : NSObject

- (instancetype) initWithSocket:(NSString*)socket success:(SuccessBlock)success failure:(FailureBlock)failure;

- (void) move:(CGVector)distance;
- (void) scroll:(CGVector)distance;
- (void) click;
- (void) button:(WebOSTVMouseButton)keyName;
- (void) sendLGKey:(LGKeyCode)keyName;
- (void) disconnect;

- (BOOL) available;

@end

typedef void (^WebOSTVServiceMouseCall)(WebOSTVServiceMouse *);
