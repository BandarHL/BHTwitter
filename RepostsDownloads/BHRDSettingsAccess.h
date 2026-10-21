#pragma once
#import "BHRDPreferences.h"
#import "BHRDSafety.h"

// Both cell construction and action callbacks use the effective runtime gate.
// The pause marker alone cannot tell whether safe boot installed feature hooks.
static inline NSString *BHRDSettingsKeyForTag(NSInteger tag) {
    if (tag<0) return nil;
    NSArray *sections=BHRDSettingsKeys(); NSUInteger section=(NSUInteger)tag/100, row=(NSUInteger)tag%100;
    return section<sections.count && row<[sections[section] count] ? sections[section][row] : nil;
}
static inline BOOL BHRDSettingsCanChangePreference(NSUserDefaults *defaults,NSString *key) {
    if (!key.length || !defaults) return NO;
    BOOL known=NO;
    for (NSArray *section in BHRDSettingsKeys()) if ([section containsObject:key]) { known=YES; break; }
    if (!known) return NO;
    if ([key isEqual:BHRDCopyLocalOnlyKey] || [key isEqual:BHRDCopyExpiresKey]) return YES;
    if (!BHRDTweakEnabled()) return NO;
    if ([@[BHRDDirectSaveKey,BHRDDMKey,BHRDFloatingDownloadKey] containsObject:key])
        return BHRDReadPreference(defaults,BHRDDownloadKey);
    return YES;
}
static inline BOOL BHRDSettingsWritePreference(NSUserDefaults *defaults,NSString *key,BOOL value) {
    if (!BHRDSettingsCanChangePreference(defaults,key)) return NO;
    [defaults setBool:value forKey:key]; return YES;
}
