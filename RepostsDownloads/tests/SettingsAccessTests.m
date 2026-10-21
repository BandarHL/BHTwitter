#import "../BHRDSettingsAccess.h"
static NSUInteger Checks;
static void Check(BOOL ok,NSString *message) { Checks++; if (!ok) { NSLog(@"FAIL: %@",message); exit(1); } }
int main(int argc,const char **argv) { @autoreleasepool {
    BOOL cold=argc>1 && strcmp(argv[1],"cold")==0;
    NSString *suite=[@"XSuixinSettingsTests-" stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    Check(BHRDFeatureHooksEnabledAtLaunch()==!cold,@"Use the actual persisted startup flag, including an actual new safe-boot process");
    Check([BHRDSettingsKeyForTag(100) isEqual:BHRDDownloadKey] && [BHRDSettingsKeyForTag(601) isEqual:BHRDCopyExpiresKey],@"Switch tags resolve to the production settings keys");
    Check(!BHRDSettingsKeyForTag(-1) && !BHRDSettingsKeyForTag(9999) && !BHRDSettingsKeyForTag(104),@"Invalid stale tags cannot address or write an arbitrary preference");
    Check(BHRDSettingsCanChangePreference(defaults,BHRDDownloadKey)==!cold,@"Visible feature controls reflect whether hooks were installed for this process");
    NSError *error=nil;
    Check(BHRDSetPaused(YES,&error) && !error,@"Pause changes the real safety state");
    BOOL before=BHRDReadPreference(defaults,BHRDDownloadKey);
    Check(!BHRDSettingsWritePreference(defaults,BHRDDownloadKey,!before) && BHRDReadPreference(defaults,BHRDDownloadKey)==before,@"A callback from a switch created before pause cannot change its stored preference");
    Check(!BHRDSettingsCanChangePreference(defaults,BHRDDownloadKey),@"Rebuilding visible rows after pause disables the same switch");
    Check(BHRDSettingsWritePreference(defaults,BHRDCopyLocalOnlyKey,NO) && !BHRDReadPreference(defaults,BHRDCopyLocalOnlyKey),@"Explicit clipboard privacy choices remain available during pause");
    Check(BHRDSettingsWritePreference(defaults,BHRDCopyExpiresKey,YES) && BHRDReadPreference(defaults,BHRDCopyExpiresKey),@"Expiry privacy choice is independently editable too");
    Check(BHRDSetPaused(NO,&error) && !BHRDIsPaused(),@"Recovery removes the marker");
    Check(BHRDSettingsCanChangePreference(defaults,BHRDDownloadKey)==!cold,@"Clearing the marker during safe boot does not pretend hooks have been loaded");
    Check(BHRDSettingsWritePreference(defaults,BHRDDownloadKey,NO)==!cold,@"Write-time guard also requires restart when recovering from safe boot");
    if (!cold) {
        Check(!BHRDSettingsCanChangePreference(defaults,BHRDDirectSaveKey) && !BHRDSettingsCanChangePreference(defaults,BHRDDMKey) && !BHRDSettingsCanChangePreference(defaults,BHRDFloatingDownloadKey),@"Turning the download parent off disables dependent controls");
        BOOL saved=BHRDReadPreference(defaults,BHRDDMKey);
        Check(!BHRDSettingsWritePreference(defaults,BHRDDMKey,!saved) && BHRDReadPreference(defaults,BHRDDMKey)==saved,@"A dependent switch's delayed callback cannot mutate disabled settings");
        Check(BHRDSettingsWritePreference(defaults,BHRDDownloadKey,YES) && BHRDSettingsWritePreference(defaults,BHRDDMKey,NO),@"Re-enabling a loaded feature restores legitimate changes");
    }
    Check(!BHRDSettingsWritePreference(defaults,@"unknown-key",YES) && ![defaults objectForKey:@"unknown-key"],@"Unknown preference names cannot be written through the settings action");
    [defaults removePersistentDomainForName:suite];
    NSLog(@"Settings access checks passed: %lu (%@ boot)",(unsigned long)Checks,cold ? @"safe" : @"normal");
} return 0; }
