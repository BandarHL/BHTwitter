#import <Foundation/Foundation.h>

// Main-thread UI evidence only. Never reads media URLs, variants or qualities.
// This can recognize a loading/current video before its download model exists.
BOOL BHRDHasVisibleFullscreenVideo(id controller);
BOOL BHRDHasSelectedFullscreenPhoto(id controller);
