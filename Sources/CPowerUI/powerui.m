#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include "powerui.h"

#if !__has_feature(objc_arc)
#error "powerui.m relies on ARC for the client's lifetime"
#endif

static const char *kPowerUIPath =
    "/System/Library/PrivateFrameworks/PowerUI.framework/Versions/A/PowerUI";

// Method encodings as PowerUI reports them on macOS 26.7 (25G229):
//   initWithClientName:              @24@0:8@16
//   isMCLSupported                   B16@0:8
//   getMCLLimitWithError:            C24@0:8^@16
//   setMCLLimit:error:               B28@0:8C16^@20
//   isMCLCurrentlyEnabled:           Q24@0:8^@16
//   availableChargeLimitsWithError:  @24@0:8^@16
//   disableMCL:                      B24@0:8^@16
typedef BOOL (*BoolFn)(id, SEL);
typedef unsigned char (*UCharErrFn)(id, SEL, NSError **);
typedef BOOL (*BoolUCharErrFn)(id, SEL, unsigned char, NSError **);
typedef unsigned long long (*ULLErrFn)(id, SEL, NSError **);
typedef id (*IdErrFn)(id, SEL, NSError **);
typedef BOOL (*BoolErrFn)(id, SEL, NSError **);

// Created once and kept for the process. Callers serialize (the daemon's lock).
static id gClient = nil;
static BOOL gProbed = NO;

static id client(void) {
    if (gProbed) return gClient;
    gProbed = YES;
    if (dlopen(kPowerUIPath, RTLD_NOW) == NULL) return nil;
    Class cls = NSClassFromString(@"PowerUISmartChargeClient");
    if (cls == Nil) return nil;
    SEL init = sel_registerName("initWithClientName:");
    if (![cls instancesRespondToSelector:init]) return nil;
    id instance = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], init, @"ewiz");
    const char *needed[] = {
        "isMCLSupported", "getMCLLimitWithError:", "setMCLLimit:error:",
        "isMCLCurrentlyEnabled:", "availableChargeLimitsWithError:", "disableMCL:",
    };
    for (size_t i = 0; i < sizeof needed / sizeof *needed; i++) {
        if (![instance respondsToSelector:sel_registerName(needed[i])]) return nil;
    }
    gClient = instance;
    return gClient;
}

int ewiz_powerui_supported(void) {
    @autoreleasepool {
        id c = client();
        if (c == nil) return 0;
        return ((BoolFn)objc_msgSend)(c, sel_registerName("isMCLSupported")) ? 1 : 0;
    }
}

int ewiz_powerui_available_limits(int *limits, int max, int *count) {
    @autoreleasepool {
        id c = client();
        if (c == nil) return -1;
        NSError *error = nil;
        id result = ((IdErrFn)objc_msgSend)(c, sel_registerName("availableChargeLimitsWithError:"), &error);
        if (![result isKindOfClass:[NSArray class]]) return -1;
        int n = 0;
        for (id value in (NSArray *)result) {
            if (n >= max) break;
            if ([value respondsToSelector:@selector(intValue)]) limits[n++] = [value intValue];
        }
        *count = n;
        return 0;
    }
}

int ewiz_powerui_get_limit(int *limit, int *enabled) {
    @autoreleasepool {
        id c = client();
        if (c == nil) return -1;
        NSError *error = nil;
        unsigned char value = ((UCharErrFn)objc_msgSend)(c, sel_registerName("getMCLLimitWithError:"), &error);
        if (error != nil) return -1;
        unsigned long long on = ((ULLErrFn)objc_msgSend)(c, sel_registerName("isMCLCurrentlyEnabled:"), &error);
        if (error != nil) return -1;
        *limit = (int)value;
        *enabled = on != 0 ? 1 : 0;
        return 0;
    }
}

int ewiz_powerui_set_limit(int limit) {
    @autoreleasepool {
        id c = client();
        if (c == nil || limit < 0 || limit > 100) return -1;
        NSError *error = nil;
        BOOL ok = ((BoolUCharErrFn)objc_msgSend)(c, sel_registerName("setMCLLimit:error:"),
                                                 (unsigned char)limit, &error);
        return ok ? 0 : -1;
    }
}

int ewiz_powerui_disable(void) {
    @autoreleasepool {
        id c = client();
        if (c == nil) return -1;
        NSError *error = nil;
        BOOL ok = ((BoolErrFn)objc_msgSend)(c, sel_registerName("disableMCL:"), &error);
        return ok ? 0 : -1;
    }
}
