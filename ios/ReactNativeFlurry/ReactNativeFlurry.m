/*
 * Copyright 2018, Oath Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ReactNativeFlurry.h"
#import "Flurry/Flurry.h"

#if TARGET_OS_IOS
#ifdef HAS_MESSAGING
#import "FlurryMessaging/FlurryMessaging.h"
#import "ReactNativeFlurryMessagingListener.h"
#endif
#import "FlurryConfig/FConfig.h"
#import "ReactNativeFlurryConfigListener.h"
#endif

#if __has_include(<React/RCTBridge.h>)
#import <React/RCTBridge.h>
#else
#import "RCTBridge.h"
#endif

#if __has_include(<React/RCTEventDispatcher.h>)
#import <React/RCTEventDispatcher.h>
#else
#import "RCTEventDispatcher.h"
#endif

static NSString * const originName = @"react-native-flurry-sdk";
static NSString * const originVersion = @"3.7.0";

@interface ReactNativeFlurry ()<RNFlurryEventDispatcherDelegate>

@property (strong, nonatomic) FlurrySessionBuilder *sessionBuilder;
@property (assign, nonatomic) FlurryLogLevel logLevel;
@property (assign, nonatomic) BOOL isActive;

#if TARGET_OS_IOS
#ifdef HAS_MESSAGING
@property (strong, nonatomic) ReactNativeFlurryMessagingListener *messagingListener;
#endif
@property (strong, nonatomic) ReactNativeFlurryConfigListener *configListener;
#endif

@end

@implementation ReactNativeFlurry

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

static ReactNativeFlurry *gInstance;

+ (void)initialize {
    if (self == ReactNativeFlurry.class) {
        gInstance = [[ReactNativeFlurry alloc] init];
    }
}

- (instancetype)init {
    if (gInstance != nil) {
        return gInstance;
    }
    
    self = [super init];
    if (self) {
        _logLevel = FlurryLogLevelCriticalOnly; // default log level
        _sessionBuilder = [FlurrySessionBuilder new];
        _isActive = NO;
        [Flurry addOrigin:originName withVersion:originVersion];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reactNativeJavaScriptDidFinishLoad)
                                                     name:RCTJavaScriptDidLoadNotification
                                                   object:nil];
    }
    
    return self;
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Flurry Builder methods

RCT_EXPORT_METHOD(initBuilder) {
    if (self.sessionBuilder == nil) {
        self.sessionBuilder = [FlurrySessionBuilder new];
    }
}

RCT_EXPORT_METHOD(build:(nonnull NSString *)apiKey) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Flurry startSession:apiKey withSessionBuilder:self.sessionBuilder];
    });
}

RCT_EXPORT_METHOD(withCrashReporting:(BOOL)crashReporting) {
    [self.sessionBuilder withCrashReporting:crashReporting];
}

RCT_EXPORT_METHOD(withContinueSessionMillis:(NSInteger)value) {
    double seconds = (double) value / 1000.0;
    [self.sessionBuilder withSessionContinueSeconds:(NSInteger)(round(seconds))];
}

RCT_EXPORT_METHOD(withIncludeBackgroundSessionsInMetrics:(BOOL)value) {
    [self.sessionBuilder withIncludeBackgroundSessionsInMetrics:value];
}

RCT_EXPORT_METHOD(withLogEnabled:(BOOL)enabled) {
    if (enabled) {
        [self.sessionBuilder withLogLevel:self.logLevel];
    } else {
        [self.sessionBuilder withLogLevel:FlurryLogLevelNone];
    }
}

RCT_EXPORT_METHOD(withLogLevel:(NSInteger)value) {
    if (value < 2 || value > 7) {
        NSLog(@"Flurry: Invalid log level %ld.", (long)value);
        return;
    }
    
    if (value == 2) {
        self.logLevel = FlurryLogLevelAll;
    } else if (value <= 5) {
        self.logLevel = FlurryLogLevelDebug;
    } else {
        self.logLevel = FlurryLogLevelCriticalOnly;
    }
    
    [self.sessionBuilder withLogLevel:self.logLevel];
}

RCT_EXPORT_METHOD(withMessaging:(BOOL)enableMessaging) {
#if TARGET_OS_IOS
    if (enableMessaging) {
        [self.class enableMessaging];
    }
#endif
}

RCT_EXPORT_METHOD(withTVSessionReportingInterval:(NSInteger)value) {
#if TARGET_OS_TV
    [self.sessionBuilder withTVSessionReportingInterval:value];
#endif
}

RCT_EXPORT_METHOD(withTVEventCountThreshold:(NSInteger)value) {
#if TARGET_OS_TV
    [self.sessionBuilder withTVEventCountThreshold:value];
#endif
}

#pragma mark - React Native API methods

RCT_EXPORT_METHOD(setAge:(int)age) {
    [Flurry setAge:age];
}

RCT_EXPORT_METHOD(setGender:(nonnull NSString *)gender) {
    [Flurry setGender:[gender lowercaseString]];
}

RCT_EXPORT_METHOD(setReportLocation:(BOOL)location) {
    [Flurry trackPreciseLocation:location];
}

RCT_EXPORT_METHOD(setSessionOrigin:(nonnull NSString *)sessionOrigin deepLink:(nonnull NSString *)deepLink) {
    [Flurry addSessionOrigin:sessionOrigin withDeepLink:deepLink];
}

RCT_EXPORT_METHOD(setUserId:(nullable NSString *)userId) {
    [Flurry setUserID:userId];
}

RCT_EXPORT_METHOD(setVersionName:(nonnull NSString *)version) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [Flurry setAppVersion:version];
#pragma clang diagnostic pop
}

RCT_EXPORT_METHOD(setIAPReportingEnabled:(BOOL)enableIAP) {
    [Flurry setIAPReportingEnabled:enableIAP];
}

RCT_EXPORT_METHOD(addOrigin:(nonnull NSString *)originName originVersion:(nonnull NSString *)originVersion) {
    [Flurry addOrigin:originName withVersion:originVersion];
}

RCT_EXPORT_METHOD(addOriginParams:(nonnull NSString *)originName originVersion:(nonnull NSString *)originVersion originParameters:(nullable NSDictionary *)originParameters) {
    [Flurry addOrigin:originName withVersion:originVersion withParameters:originParameters];
}

RCT_EXPORT_METHOD(addSessionProperty:(nonnull NSString *)name value:(nonnull NSString *)value) {
    NSDictionary *sessionProperties = @{name: value};
    [Flurry sessionProperties:sessionProperties];
}

RCT_EXPORT_METHOD(getVersions:(RCTResponseSenderBlock)errorCallback successCallback:(RCTResponseSenderBlock)successCallback) {
    NSString *agentVersion = [Flurry getFlurryAgentVersion];
    NSString *sessionId = [Flurry getSessionID];
    successCallback(@[agentVersion, [NSNull null], sessionId]);
}

RCT_REMAP_METHOD(getVersionsPromise, getVersionsPromiseWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        // Please note that AgentVersion on iOS platform is equivalent to ReleaseVersion on Android platform.
        NSString *releaseVersion = [Flurry getFlurryAgentVersion];
        NSString *sessionId = [Flurry getSessionID];
        NSDictionary *map = @{@"agentVersion": [NSNull null],
                              @"releaseVersion": releaseVersion,
                              @"sessionId": sessionId};
        resolve(map);
    } @catch (NSException *exception) {
        reject([exception description], [exception reason], nil);
    }
}

RCT_EXPORT_METHOD(logEvent:(nonnull NSString *)eventId) {
    [Flurry logEvent:eventId];
}

RCT_EXPORT_METHOD(logEventTimed:(nonnull NSString *)eventId timed:(BOOL)timed) {
    [Flurry logEvent:eventId timed:timed];
}

RCT_EXPORT_METHOD(logEventParams:(nonnull NSString *)eventId parameters:(nullable NSDictionary *)params) {
    [Flurry logEvent:eventId withParameters:params];
}

RCT_EXPORT_METHOD(logEventParamsTimed:(nonnull NSString *)eventId parameters:(nullable NSDictionary *)params timed:(BOOL)timed) {
    [Flurry logEvent:eventId withParameters:params timed:timed];
}

RCT_EXPORT_METHOD(endTimedEvent:(nonnull NSString *)eventId) {
    [Flurry endTimedEvent:eventId withParameters:nil];
}

RCT_EXPORT_METHOD(endTimedEventParams:(nonnull NSString *)eventId params:(nullable NSDictionary *)params) {
    [Flurry endTimedEvent:eventId withParameters:params];
}

RCT_EXPORT_METHOD(logBreadcrumb:(nonnull NSString *)breadcrumb) {
    [Flurry leaveBreadcrumb:breadcrumb];
}

RCT_EXPORT_METHOD(logPayment:(NSString *)productName productId:(NSString *)productId quantity:(NSInteger)quantity price:(double)price currency:(NSString *)currency transactionId:(NSString *)transactionId parameters:(NSDictionary *)parameters) {
    NSLog(@"Flurry.logPayment is not supported on iOS. Please use Flurry.setIAPReportingEnabled instead.");
}

RCT_EXPORT_METHOD(onPageView) {
#if TARGET_OS_IOS
    [Flurry logPageView];
#endif
}

RCT_EXPORT_METHOD(onError:(nonnull NSString *)errorId message:(nullable NSString *)message errorClass:(nullable NSString *)errorClass) {
    NSError *error = nil;
    if (errorClass != nil) {
        error = [NSError errorWithDomain:errorClass code:0 userInfo:nil];
    }
    [Flurry logError:errorId message:message error:error];
}

RCT_EXPORT_METHOD(onErrorParams:(nonnull NSString *)errorId message:(nullable NSString *)message errorClass:(nullable NSString *)errorClass parameters:(nullable NSDictionary *)parameters) {
    NSError *error = nil;
    if (errorClass != nil) {
        error = [NSError errorWithDomain:errorClass code:0 userInfo:nil];
    }
    [Flurry logError:errorId message:message error:error withParameters:parameters];
}

#pragma mark - Flurry Messaging

RCT_EXPORT_METHOD(enableMessagingListener:(BOOL)enabled) {
#if TARGET_OS_IOS
#ifdef HAS_MESSAGING
    [ReactNativeFlurryMessagingListener messagingListener].messagingListenerEnabled = enabled;
#else
    [self handleMessagingNotFound];
#endif
#endif
}

RCT_EXPORT_METHOD(willHandleMessage:(BOOL)handled) {
    NSLog(@"Flurry.willHandleMessage is not supported on iOS and tvOS.");
}

#pragma mark - Flurry Config

RCT_EXPORT_METHOD(registerConfigListener) {
#if TARGET_OS_IOS
    if (!self.configListener) {
        self.configListener = [ReactNativeFlurryConfigListener configListener];
        self.configListener.delegate = self;
        [[FConfig sharedInstance] registerObserver:self.configListener withExecutionQueue:self.configListener.queue];
    }
    [self.configListener addCallback];
#endif
}

RCT_EXPORT_METHOD(unregisterConfigListener) {
#if TARGET_OS_IOS
    [self.configListener removeCallback];
#endif
}

RCT_EXPORT_METHOD(fetchConfig) {
#if TARGET_OS_IOS
    [[FConfig sharedInstance] fetchConfig];
#endif
}

RCT_EXPORT_METHOD(activateConfig) {
#if TARGET_OS_IOS
    [[FConfig sharedInstance] activateConfig];
#endif
}

RCT_REMAP_METHOD(getConfigString, getConfigString:(nonnull NSString *)key defaultValue:(nonnull NSString *)defaultValue resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
#if TARGET_OS_IOS
    @try {
        NSString *value = [[FConfig sharedInstance] getStringForKey:key withDefault:defaultValue];
        NSDictionary *map = @{key: value};
        resolve(map);
    } @catch (NSException *exception) {
        reject([exception description], [exception reason], nil);
    }
#endif
}

RCT_REMAP_METHOD(getConfigStringMap, getConfigStringMap:(nonnull NSDictionary *)defaultMap resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
#if TARGET_OS_IOS
    @try {
        NSMutableDictionary<NSString *, NSString *> *map = [NSMutableDictionary dictionary];
        for (NSString *key in defaultMap) {
            NSString *val = [[FConfig sharedInstance] getStringForKey:key withDefault:defaultMap[key]];
            map[key] = val;
        }
        resolve(map);
    } @catch (NSException *exception) {
        reject([exception description], [exception reason], nil);
    }
#endif
}

#pragma mark - Flurry Event Dispatcher delegate

- (void)sendEvent:(NSString *)event params:(NSDictionary *)params {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self.bridge.eventDispatcher sendAppEventWithName:event body:params];
#pragma clang diagnostic pop
}

- (BOOL)canAcceptEvents {
    return self.isActive;
}

#pragma mark - Notification listener

- (void)reactNativeJavaScriptDidFinishLoad {
    self.isActive = YES;
#if TARGET_OS_IOS
#ifdef HAS_MESSAGING
    [[ReactNativeFlurryMessagingListener messagingListener] sendPendingEvents];
#endif
#endif
}

#pragma mark - Native API

#if TARGET_OS_IOS
+ (void)enableMessaging {
#ifdef HAS_MESSAGING
    static dispatch_once_t messagingToken;
    dispatch_once(&messagingToken, ^{
        [FlurryMessaging setAutoIntegrationForMessaging];
        gInstance.messagingListener = [ReactNativeFlurryMessagingListener messagingListener];
        [FlurryMessaging setMessagingDelegate:gInstance.messagingListener];
        gInstance.messagingListener.delegate = gInstance;
    });
#else
    [gInstance handleMessagingNotFound];
#endif
}
#endif

#pragma mark - Private helpers

- (void)handleMessagingNotFound {
    NSLog(@"Flurry: You are using `libReactNativeFlurry.a` instead of `libReactNativeFlurryWithMessaging.a`. Please re-link react-native-flurry-sdk by executing\n\treact-native unlink react-native-flurry-sdk && react-native link react-native-flurry-sdk\nand type Y while being asked if you need to integrate Flurry Push.");
}

@end
