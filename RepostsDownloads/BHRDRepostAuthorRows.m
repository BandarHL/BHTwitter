#import "BHRDRepostAuthor.h"
#import <objc/message.h>
#import <math.h>

static NSString *ReadText(id value, NSUInteger depth) {
    if (!value || value == NSNull.null || depth > 4) return nil;
    if ([value isKindOfClass:NSAttributedString.class]) value = [value string];
    if ([value isKindOfClass:NSString.class]) {
        // X wraps handles in Unicode direction controls, including LRI/LRE
        // and PDF/PDI. They format the label but are not part of its identity.
        // Keep zero-width joiners: display names can contain joined emoji.
        static NSCharacterSet *directions; static dispatch_once_t once;
        dispatch_once(&once, ^{ directions = [NSCharacterSet characterSetWithCharactersInString:@"\u061C\u200E\u200F\u202A\u202B\u202C\u202D\u202E\u2066\u2067\u2068\u2069"]; });
        NSString *text = [[value componentsSeparatedByCharactersInSet:directions] componentsJoinedByString:@""];
        text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return text.length ? text : nil;
    }
    for (NSString *key in @[@"attributedText", @"text", @"attributedString", @"string", @"textModel"]) {
        SEL selector = NSSelectorFromString(key);
        NSMethodSignature *sig = [value methodSignatureForSelector:selector];
        if (sig.numberOfArguments != 2 || sig.methodReturnType[0] != '@') continue;
        id child = ((id (*)(id, SEL))objc_msgSend)(value, selector);
        NSString *text = child != value ? ReadText(child, depth + 1) : nil;
        if (text) return text;
    }
    return nil;
}
NSString *BHRDRepostHeaderText(id source) { return ReadText(source, 0); }

static BOOL AccessibilityMetadata(NSString *suffix) {
    if ([suffix isEqual:@"。"] || [suffix isEqual:@"."]) return YES;
    // Only recognized author metadata may follow the complete handle. Do not
    // accept arbitrary sentences or ellipses that could hide a truncated name.
    static NSRegularExpression *metadata; static dispatch_once_t once;
    dispatch_once(&once, ^{
        metadata = [NSRegularExpression regularExpressionWithPattern:@"^[。.,，]\\s*(?:已验证|已认证|Verified(?: account)?|按钮|Button)(?:$|[。.,，\\s])" options:NSRegularExpressionCaseInsensitive error:nil];
    });
    return [metadata firstMatchInString:suffix options:0 range:NSMakeRange(0, suffix.length)] != nil;
}

NSDictionary *BHRDSelectRepostAuthor(NSArray<NSDictionary *> *rows, NSString *expectedHandle) {
    expectedHandle = [BHRDRepostHeaderText(expectedHandle) stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@ "]];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?<![A-Za-z0-9_])@([A-Za-z0-9_]{1,15})(?![A-Za-z0-9_])" options:0 error:nil];
    NSArray *ordered = [rows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        BOOL sa = [a[@"semantic"] boolValue], sb = [b[@"semantic"] boolValue];
        if (sa != sb) return sa ? NSOrderedAscending : NSOrderedDescending;
        NSComparisonResult y = [a[@"y"] compare:b[@"y"]];
        return y == NSOrderedSame ? [a[@"x"] compare:b[@"x"]] : y;
    }];
    for (NSDictionary *row in ordered) {
        NSString *text = BHRDRepostHeaderText(row[@"text"]);
        if (!text || [text containsString:@"\n"] || [row[@"body"] boolValue] || [text hasPrefix:@"回复"] || [text hasPrefix:@"Replying"] || [text hasPrefix:@"RT "]) continue;
        double y = [row[@"y"] doubleValue];
        if (y < 0 || y > 110) continue;
        NSArray *matches = [regex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
        if (matches.count != 1) continue;
        NSTextCheckingResult *match = matches.firstObject;
        NSString *handle = [text substringWithRange:[match rangeAtIndex:1]];
        if (expectedHandle.length && [handle caseInsensitiveCompare:expectedHandle] != NSOrderedSame) continue;
        NSString *suffix = [[text substringFromIndex:NSMaxRange(match.range)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        BOOL accessibility = [row[@"accessibility"] boolValue] && [row[@"semantic"] boolValue];
        if (suffix.length && ![suffix hasPrefix:@"·"] && ![suffix hasPrefix:@"•"] && !(accessibility && AccessibilityMetadata(suffix))) continue;
        NSString *name = [[text substringToIndex:match.range.location] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ·•\t"]];
        if (accessibility && ([name hasSuffix:@"。"] || [name hasSuffix:@"."]))
            name = [[name substringToIndex:name.length - 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (name.length > 90 || [name containsString:@"转推"] || [name containsString:@"转发"] || [name.lowercaseString containsString:@"reposted"] || [name.lowercaseString containsString:@"retweeted"]) continue;
        if (!name.length) {
            double best = HUGE_VAL;
            for (NSDictionary *candidate in ordered) {
                NSString *value = BHRDRepostHeaderText(candidate[@"text"]);
                double dy = y - [candidate[@"y"] doubleValue];
                if (candidate == row || [candidate[@"body"] boolValue] || !value.length || value.length > 90 || [value containsString:@"@"] || [value containsString:@"\n"] || [value containsString:@"转推"] || [value containsString:@"转发"] || [value.lowercaseString containsString:@"repost"] || [value.lowercaseString containsString:@"retweet"] || [value hasPrefix:@"http"]) continue;
                if (dy < -8 || dy > 32) continue;
                if (fabs(dy) < 8 && [candidate[@"x"] doubleValue] >= [row[@"x"] doubleValue]) continue;
                if (fabs(dy) < best) { best = fabs(dy); name = value; }
            }
        }
        return @{@"name": name ?: @"", @"handle": handle, @"y": row[@"y"] ?: @0};
    }
    return nil;
}
