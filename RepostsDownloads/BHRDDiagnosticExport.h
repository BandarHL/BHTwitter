#pragma once
#import <Foundation/Foundation.h>
#import <math.h>

// Export is a closed schema. Local raw logs are untouched; unknown event fields,
// free text, identifiers and URL aliases have no export path.
static inline NSSet *BHRDExportWords(NSString *words) {
    return [NSSet setWithArray:[words componentsSeparatedByString:@" "]];
}
static inline NSSet *BHRDExportCodes(void) {
    static NSSet *codes; static dispatch_once_t once;
    dispatch_once(&once,^{ codes=[NSSet setWithArray:@[
#include "BHRDDiagnosticExportVocabulary.inc"
    ]]; }); return codes;
}
static inline NSSet *BHRDExportEvents(void) {
    static NSSet *events; static dispatch_once_t once;
    dispatch_once(&once,^{ events=[NSSet setWithArray:@[
#include "BHRDDiagnosticExportEvents.inc"
    ]]; }); return events;
}
static inline BOOL BHRDExportMatches(NSString *value, NSString *pattern) {
    return [value isKindOfClass:NSString.class] && value.length<=256 &&
        [value rangeOfString:pattern options:NSRegularExpressionSearch].location!=NSNotFound;
}
static inline NSSet *BHRDExportFields(NSString *event) {
    static NSDictionary *groups; static dispatch_once_t once;
    dispatch_once(&once,^{ groups=@{
        @"video":BHRDExportWords(@"phase reason stage sourceClass sourcePath resourceAccess endpointCount playerCount modelCount visibleSourceCount examinedViewCount scanTruncated resolvedPlayerCount unresolvedPlayerCount resolvedSourceCount unresolvedSourceCount candidateResults resourceDecisionCounts resourceProbePaths excludedPlaybackBranches unresolvedReasons observedViewClasses detailedResourceProbe resourceProbes nativeVariantProbes currentItemShapes getters detailedNativeProbe primaryDecision rejectionCounts kind currentItemPresent resolved displayed attached modal frame ownerClass path access schemeCategory hostCategory extensionCategory contentTypeCategory sample class getter returnKind videoInfoPresent variantsCategory variantCount acceptedVariantCount mediaCount assetCount requiresPlaybackMatch playingAssetConfirmed attempt acceptanceSession"),
        @"home":BHRDExportWords(@"stage examinedViewCount cellExcludedCount visibilityExcludedCount regionExcludedCount candidateCount scanTruncated firstTabFound secondTabFound addHiddenCount pagerVerified rejectionCounts"),
        @"ad":BHRDExportWords(@"bytes marker changed eventCount totalBytes maxWindowSeconds"),
        @"photo":BHRDExportWords(@"phase reason stage success image source fallback width height pixelWidth pixelHeight bytes permission authorizationStatus status type committed duplicate late cancelled elapsedMs errorDomain errorCode current available loaded count candidateCount examinedViewCount scanTruncated candidates selected sourcePath sourceClass path access class getter returnKind present result imageAvailable bitmapSource identityVerified payloadType attempt acceptanceSession"),
        @"stream":BHRDExportWords(@"job acceptanceSession phase elapsedMs engineState sessionID engineDurationMs returnCode engineStarted diagnosticTail readTimeoutMs watchdogSeconds late success result streamCount videoStreamCount reason errorDomain errorCode bytes mediaTimeMs"),
        @"performance":BHRDExportWords(@"status pendingReason active running visibleSeconds elapsedSeconds maximumSeconds frameIntervals slowIntervals slowIntervalThresholdMs slowIntervalRatio maxIntervalMs memoryMB peakMemoryMB memorySource thermalState memoryWarnings measurement stopReason batteryMeasurement acceptanceSession thresholdExceeded"),
        @"repost":BHRDExportWords(@"phase reason result source class modelClass viewClass loaded found success confirmed observable hiddenPreserved detailsShown count retry current late nativeAvailable height attempts"),
        @"avatar":BHRDExportWords(@"phase reason result source class modelClass viewClass loaded found success http bytes count retry current late width height hasImage hasURL"),
        @"safety":BHRDExportWords(@"paused success hooksEnabledAtLaunch disabledFile persisted shown source reason errorDomain errorCode"),
        @"other":BHRDExportWords(@"phase enabled durationSeconds success result reason errorDomain errorCode")
    }; });
    NSString *group=[event hasPrefix:@"fullscreen_video"] || [event isEqual:@"fullscreen_download_visibility"] ? @"video" : [event hasPrefix:@"home_"] ? @"home" : [event hasPrefix:@"ad_"] ? @"ad" : [event containsString:@"photo"] ? @"photo" : [event hasPrefix:@"stream_"] ? @"stream" : [event hasPrefix:@"performance_"] ? @"performance" : [event hasPrefix:@"repost_"] ? @"repost" : [event hasPrefix:@"safety_"] || [event hasPrefix:@"recovery_"] ? @"safety" : [event containsString:@"avatar"] || [event hasPrefix:@"model_"] || [event hasPrefix:@"native_"] ? @"avatar" : @"other";
    return groups[group];
}
static inline BOOL BHRDExportPath(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length>384) return NO;
    NSCharacterSet *separators=[NSCharacterSet characterSetWithCharactersInString:@". ()[]"];
    for (NSString *part in [value componentsSeparatedByCharactersInSet:separators]) {
        if (!part.length) continue;
        if (![BHRDExportCodes() containsObject:part] && !BHRDExportMatches(part,@"^[0-9]{1,3}$")) return NO;
    }
    return YES;
}
static inline id BHRDExportValue(id value, NSString *key, NSSet *fields, NSUInteger depth);
static inline NSDictionary *BHRDExportObject(NSDictionary *input, NSSet *fields, NSUInteger depth) {
    if (depth>6 || ![input isKindOfClass:NSDictionary.class]) return @{};
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    for (NSString *key in fields) {
        id safe=BHRDExportValue(input[key],key,fields,depth+1); if (safe) result[key]=safe;
    }
    return result;
}
static inline id BHRDExportValue(id value, NSString *key, NSSet *fields, NSUInteger depth) {
    if (!value || depth>6) return nil;
    static NSSet *numeric,*boolean,*enumerated,*paths,*containers,*identifiers,*domains; static dispatch_once_t once;
    dispatch_once(&once,^{
        numeric=BHRDExportWords(@"endpointCount playerCount modelCount visibleSourceCount examinedViewCount resolvedPlayerCount unresolvedPlayerCount resolvedSourceCount unresolvedSourceCount sample variantCount acceptedVariantCount mediaCount assetCount cellExcludedCount visibilityExcludedCount regionExcludedCount candidateCount addHiddenCount bytes eventCount totalBytes maxWindowSeconds width height pixelWidth pixelHeight authorizationStatus elapsedMs errorCode count elapsedSeconds maximumSeconds durationSeconds engineDurationMs returnCode readTimeoutMs watchdogSeconds streamCount videoStreamCount mediaTimeMs visibleSeconds frameIntervals slowIntervals slowIntervalThresholdMs slowIntervalRatio maxIntervalMs memoryMB peakMemoryMB memoryWarnings http retry attempts");
        boolean=BHRDExportWords(@"scanTruncated currentItemPresent resolved displayed attached modal videoInfoPresent requiresPlaybackMatch playingAssetConfirmed firstTabFound secondTabFound pagerVerified marker changed success image fallback committed duplicate late cancelled current available loaded selected present imageAvailable identityVerified engineStarted active running thresholdExceeded found confirmed observable hiddenPreserved detailsShown nativeAvailable hasImage hasURL paused hooksEnabledAtLaunch disabledFile persisted shown enabled");
        enumerated=BHRDExportWords(@"phase reason stage sourceClass ownerClass resourceAccess kind access schemeCategory hostCategory extensionCategory contentTypeCategory class getter returnKind variantsCategory source permission result bitmapSource payloadType engineState status pendingReason memorySource thermalState measurement stopReason batteryMeasurement modelClass viewClass diagnosticTail unresolvedReasons observedViewClasses");
        paths=BHRDExportWords(@"path sourcePath resourceProbePaths excludedPlaybackBranches");
        containers=BHRDExportWords(@"candidateResults detailedResourceProbe resourceProbes nativeVariantProbes currentItemShapes getters detailedNativeProbe primaryDecision candidates");
        identifiers=BHRDExportWords(@"job attempt acceptanceSession");
        domains=BHRDExportWords(@"NSCocoaErrorDomain NSURLErrorDomain PHPhotosErrorDomain com.caun.xsuixin.photo-save XSuixinSafety PhotosError BHRDStream BHRDBusy redacted");
    });
    if ([key isEqual:@"resourceDecisionCounts"] || [key isEqual:@"rejectionCounts"]) {
        NSMutableDictionary *counts=[NSMutableDictionary dictionary];
        for (NSString *reason in @[@"absent",@"invalid_or_non_url",@"unsupported_scheme",@"unsupported_host",@"unsupported_extension",@"unsupported_content_type",@"accepted",@"source_outside_home",@"content_cell_excluded",@"add_role_unconfirmed",@"primary_row_mismatch",@"shared_header_unconfirmed",@"plus_not_trailing",@"hit_target_unavailable",@"shared_primary_control",@"add_geometry_unconfirmed"]) {
            id n=[value isKindOfClass:NSDictionary.class] ? value[reason] : nil;
            if ([n isKindOfClass:NSNumber.class] && isfinite([n doubleValue]) && [n doubleValue]>=0 && [n doubleValue]<=10000) counts[reason]=n;
        } return counts;
    }
    if ([key isEqual:@"status"] && [value isKindOfClass:NSNumber.class]) return [value integerValue]>=0 && [value integerValue]<=4 ? value : nil;
    if ([key isEqual:@"type"]) return [@[@"public.png",@"public.jpeg",@"com.compuserve.gif",@"public.heic",@"public.heif"] containsObject:value] ? value : @"other";
    if ([key isEqual:@"frame"]) {
        if (![value isKindOfClass:NSArray.class] || [value count]!=4) return nil;
        for (id n in value) if (![n isKindOfClass:NSNumber.class] || !isfinite([n doubleValue]) || fabs([n doubleValue])>10000) return nil;
        return value;
    }
    if ([numeric containsObject:key]) return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]) && fabs([value doubleValue])<=1e12 ? value : nil;
    if ([boolean containsObject:key]) return [value isKindOfClass:NSNumber.class] ? @([value boolValue]) : nil;
    if ([key isEqual:@"errorDomain"]) return [domains containsObject:value] ? value : @"redacted";
    if ([identifiers containsObject:key]) return [value isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:value] ? value : nil;
    if ([value isKindOfClass:NSArray.class] && ([containers containsObject:key] || [paths containsObject:key] || [enumerated containsObject:key])) {
        NSMutableArray *safe=[NSMutableArray array];
        for (id item in [(NSArray *)value subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)32,[value count]))]) {
            id child=BHRDExportValue(item,key,fields,depth+1); if (child) [safe addObject:child];
        } return safe;
    }
    if ([containers containsObject:key]) return [value isKindOfClass:NSDictionary.class] ? BHRDExportObject(value,fields,depth) : nil;
    if ([paths containsObject:key]) return BHRDExportPath(value) ? value : nil;
    if ([enumerated containsObject:key]) return [value isKindOfClass:NSString.class] && [BHRDExportCodes() containsObject:value] ? value : @"other";
    return nil;
}
static inline NSDictionary *BHRDExportDiagnosticRecord(NSDictionary *record) {
    id event=record[@"event"]; BOOL known=[BHRDExportEvents() containsObject:event];
    NSMutableDictionary *safe=[(known ? BHRDExportObject(record,BHRDExportFields(event),0) : @{}) mutableCopy];
    safe[@"event"]=known ? event : @"unrecognized_event"; safe[@"exportSchema"]=@2;
    id time=record[@"time"];
    if ([time isKindOfClass:NSNumber.class] && isfinite([time doubleValue]) && [time doubleValue]>=0 && [time doubleValue]<1e11) safe[@"time"]=time;
    if (BHRDExportMatches(record[@"build"],@"^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9]+)?$")) safe[@"build"]=record[@"build"];
    if (BHRDExportMatches(record[@"revision"],@"^[0-9]{1,6}$")) safe[@"revision"]=record[@"revision"];
    if (BHRDExportMatches(record[@"commit"],@"^(?:[0-9a-f]{40}(?:-dirty)?|development)$")) safe[@"commit"]=record[@"commit"];
    if ([@[@"Caun1112/XSuixin",@"Caun1112/BHTwitter"] containsObject:record[@"repository"] ?: @""]) safe[@"repository"]=record[@"repository"];
    return safe;
}
