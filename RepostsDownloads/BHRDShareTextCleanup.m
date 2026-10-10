#import "BHRDShareTextCleanup.h"
NSString *BHRDRemoveShareShortLinks(NSString *text) {
    if (!text.length) return text ?: @"";
    static NSRegularExpression *links, *spaces, *punctuation;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        links = [NSRegularExpression regularExpressionWithPattern:@"(?i)(?<![A-Za-z0-9_./@-])https?://t\\.co/[A-Za-z0-9_-]+(?:\\?[^\\s\\p{Han}<>\\[\\]{}()]*)?" options:0 error:nil];
        spaces = [NSRegularExpression regularExpressionWithPattern:@"[ \\t]{2,}" options:0 error:nil];
        punctuation = [NSRegularExpression regularExpressionWithPattern:@"[ \\t]+([，。！？；：,.!?;:])" options:0 error:nil];
    });
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSArray<NSTextCheckingResult *> *matches = [links matchesInString:line options:0 range:NSMakeRange(0, line.length)];
        if (!matches.count) { [lines addObject:line]; continue; }
        NSMutableString *cleaned = [line mutableCopy];
        for (NSTextCheckingResult *match in matches.reverseObjectEnumerator) {
            NSRange range = match.range;
            if (range.location && NSMaxRange(range) < line.length) {
                unichar before = [line characterAtIndex:range.location - 1], after = [line characterAtIndex:NSMaxRange(range)];
                if ((before == '(' && after == ')') || (before == '[' && after == ']') || (before == '<' && after == '>')) { range.location--; range.length += 2; }
            }
            [cleaned deleteCharactersInRange:range];
        }
        NSString *result = [spaces stringByReplacingMatchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length) withTemplate:@" "];
        result = [punctuation stringByReplacingMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"$1"];
        result = [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (result.length) [lines addObject:result];
    }
    return [[lines componentsJoinedByString:@"\n"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
BHRDSharePost *BHRDCleanSharePostForRendering(BHRDSharePost *post) {
    BHRDSharePost *copy = [post copy];
    for (BHRDSharePost *current in BHRDShareAllPosts(copy)) {
        current.title = BHRDRemoveShareShortLinks(current.title);
        current.body = BHRDRemoveShareShortLinks(current.body);
        current.translatedBody = BHRDRemoveShareShortLinks(current.translatedBody);
        current.quote = BHRDRemoveShareShortLinks(current.quote);
    }
    return copy;
}
