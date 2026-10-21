#pragma once
#import <Foundation/Foundation.h>

// The host-wide JSON hook must not treat our own persistence and log files as
// Twitter responses. Keep the scope on the parsing thread and restore nesting.
static inline BOOL BHRDReadingLocalJSON(void) {
    return [NSThread.currentThread.threadDictionary[@"com.caun.xsuixin.local-json"] boolValue];
}
static inline id BHRDReadLocalJSON(NSData *data, NSJSONReadingOptions options, NSError **error) {
    NSMutableDictionary *state = NSThread.currentThread.threadDictionary;
    NSString *key = @"com.caun.xsuixin.local-json";
    id previous = state[key];
    state[key] = @YES;
    @try { return [NSJSONSerialization JSONObjectWithData:data options:options error:error]; }
    @finally {
        if (previous) state[key] = previous;
        else [state removeObjectForKey:key];
    }
}
