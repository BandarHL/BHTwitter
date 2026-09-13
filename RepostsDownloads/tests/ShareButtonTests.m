#import <Foundation/Foundation.h>
#import "../BHRDPreferences.h"
#include <stdlib.h>
#define MOCK(name) @interface name : NSObject @end @implementation name @end
MOCK(ReplyButton)
MOCK(RepostButton)
MOCK(NativeShareButton)
MOCK(DownloadButton)
MOCK(AlbumButton)
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) { checks++; if (!pass) { NSLog(@"FAIL: %@", name); exit(1); } }
int main(void) {
    @autoreleasepool {
        NSString *suite = [@"XSuixinAlbumTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        Check(BHRDReadPreference(defaults, BHRDShowShareImageKey), @"Album entry is enabled by default on upgrade");
        [defaults setBool:NO forKey:BHRDDownloadKey];
        Check(BHRDReadPreference(defaults, BHRDShowShareImageKey), @"Disabling video downloads does not disable sharing images");
        [defaults setBool:NO forKey:BHRDShowShareImageKey];
        Check(!BHRDReadPreference(defaults, BHRDShowShareImageKey), @"Album entry can be switched off");
        [defaults setBool:YES forKey:BHRDShowShareImageKey];
        Check(BHRDReadPreference(defaults, BHRDShowShareImageKey), @"Album entry can be re-enabled independently");
        [defaults removePersistentDomainForName:suite];
        NSArray *plain = @[ReplyButton.class, RepostButton.class, NativeShareButton.class];
        NSArray *enabled = BHRDSetShareImageButtonClass(plain, AlbumButton.class, YES);
        Check([enabled isEqual:@[ReplyButton.class, RepostButton.class, NativeShareButton.class, AlbumButton.class]], @"Plain-text tweet action rows get a dedicated album entry");
        Check(plain.count == 3, @"Do not mutate the host's action array");
        Check([BHRDSetShareImageButtonClass(enabled, AlbumButton.class, YES) isEqual:enabled], @"Repeated factory calls cannot duplicate the album button");
        NSArray *duplicate = @[AlbumButton.class, NativeShareButton.class, AlbumButton.class];
        Check([BHRDSetShareImageButtonClass(duplicate, AlbumButton.class, YES) isEqual:@[AlbumButton.class, NativeShareButton.class]], @"Repair duplicate entries while preserving the existing slot");
        Check([BHRDSetShareImageButtonClass(enabled, AlbumButton.class, NO) isEqual:plain], @"Turning off removes only the album entry");
        NSArray *video = @[NativeShareButton.class, DownloadButton.class];
        Check([BHRDSetShareImageButtonClass(video, AlbumButton.class, YES) isEqual:@[NativeShareButton.class, DownloadButton.class, AlbumButton.class]], @"Video download and native sharing remain available alongside the new entry");
        Check([BHRDSetShareImageButtonClass(nil, AlbumButton.class, YES) isEqual:@[AlbumButton.class]], @"An empty factory list safely accepts the new entry");
        Check([BHRDSetShareImageButtonClass(nil, AlbumButton.class, NO) count] == 0, @"Disabled empty list stays empty");
        Check([BHRDSettingsKeys()[2] containsObject:BHRDShowShareImageKey] && [BHRDSettingsTitles()[2] containsObject:@"显示分享图片按钮"], @"Chinese toggle appears in the tweet bottom elements section");
        NSLog(@"PASS: %lu album-button policy checks", (unsigned long)checks);
    }
    return 0;
}
