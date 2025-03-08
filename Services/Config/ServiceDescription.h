//
//  ServiceDescription.h
//  Connect SDK
//
//  Created by Andrew Longstaff on 9/6/13.
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
#import "JSONObjectCoding.h"

@interface ServiceDescription : NSObject <JSONObjectCoding, NSCopying>

@property (nonatomic, strong, nonnull) NSString *address;
@property (nonatomic, strong, nullable) NSString *serviceId;
@property (nonatomic) NSUInteger port;
@property (nonatomic, strong, nonnull) NSString *UUID;
@property (nonatomic, strong, nullable) NSString *type;
@property (nonatomic, strong, nullable) NSString *version;
@property (nonatomic, strong, nullable) NSString *friendlyName;
@property (nonatomic, strong, nullable) NSString *manufacturer;
@property (nonatomic, strong, nullable) NSString *modelName;
@property (nonatomic, strong, nullable) NSString *modelDescription;
@property (nonatomic, strong, nullable) NSString *modelNumber;
@property (nonatomic, strong, nullable) NSURL *commandURL;
@property (nonatomic, strong, nullable) NSString *locationXML;
@property (nonatomic, strong, nullable) NSArray *serviceList;
@property (nonatomic, strong, nullable) NSDictionary *locationResponseHeaders;
@property (nonatomic) double lastDetection;
/**
 * @brief A device object set by a discovery provider when a service requires it (that is, it is the
 * only way to control the remote device).
 *
 * For example, @c CastService requires a @c GCKDevice object retrieved during discovery in
 * <tt>CastDiscoveryProvider</tt>. On the other hand, @c DLNAService doesn't require any specific
 * object, because it works via HTTP using other properties.
 * @note The service is responsible for checking that the property is of the expected type.
 */
@property (nonatomic, strong, nullable) id device;

- (instancetype _Nonnull)initWithAddress:(NSString * _Nonnull)address UUID:(NSString* _Nonnull)UUID;
+ (instancetype _Nonnull)descriptionWithAddress:(NSString * _Nonnull)address UUID:(NSString* _Nonnull)UUID;

- (BOOL)isEqualToServiceDescription:(ServiceDescription * _Nonnull)service;

@end
