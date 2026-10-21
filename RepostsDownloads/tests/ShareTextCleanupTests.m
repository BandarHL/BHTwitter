#import <Foundation/Foundation.h>
#import "../BHRDShareTextCleanup.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) { checks++; if (!pass) { NSLog(@"FAIL: %@", name); exit(1); } }
int main(void) {
    @autoreleasepool {
        Check([BHRDRemoveShareShortLinks(@"Thanks! https://t.co/iRHfiFxFR7") isEqual:@"Thanks!"], @"Remove the screenshot's trailing media short link");
        Check([BHRDRemoveShareShortLinks(@"正文 https://t.co/abc123。") isEqual:@"正文。"], @"Keep punctuation without a leftover gap");
        Check([BHRDRemoveShareShortLinks(@"A https://t.co/One B https://t.co/Two C") isEqual:@"A B C"], @"Remove multiple links without joining words");
        Check([BHRDRemoveShareShortLinks(@"第一段\nhttps://t.co/a1\n第二段") isEqual:@"第一段\n第二段"], @"Remove a media-only line");
        Check([BHRDRemoveShareShortLinks(@"第一段\n\n第二段 https://t.co/a1") isEqual:@"第一段\n\n第二段"], @"Preserve real paragraph separation");
        Check([BHRDRemoveShareShortLinks(@"正文 (https://t.co/abc)") isEqual:@"正文"], @"Do not leave empty URL wrappers");
        Check([BHRDRemoveShareShortLinks(@"[说明](https://t.co/abc)") isEqual:@"[说明]"], @"Keep a linked caption while removing its short URL");
        Check([BHRDRemoveShareShortLinks(@"HTTP://T.CO/Abc_123?x=1") isEqual:@""], @"Handle case, query strings and HTTP variants");
        NSString *ordinary = @"保留 https://example.com/a 与 https://x.com/i/status/123";
        Check([BHRDRemoveShareShortLinks(ordinary) isEqual:ordinary], @"Do not remove normal web links or original tweet URLs");
        NSString *lookalikes = @"https://t.co.example.com/abc https://example.com/https://t.co/abc";
        Check([BHRDRemoveShareShortLinks(lookalikes) isEqual:lookalikes], @"Match the exact hostname and URL boundary");
        Check([BHRDRemoveShareShortLinks(@"原有  双空格\n    缩进") isEqual:@"原有  双空格\n    缩进"], @"Unrelated lines keep their formatting");
        Check([BHRDRemoveShareShortLinks(nil) isEqual:@""], @"Missing text is safe");
        BHRDSharePost *post = [BHRDSharePost new]; post.body = @"Original https://t.co/original"; post.translatedBody = @"译文 https://t.co/trans"; post.link = @"https://x.com/i/status/123";
        post.quotedPost = [BHRDSharePost new]; post.quotedPost.body = @"Quote https://t.co/quote";
        BHRDSharePost *cleaned = BHRDCleanSharePostForRendering(post);
        Check([cleaned.body isEqual:@"Original"] && [cleaned.translatedBody isEqual:@"译文"] && [cleaned.quotedPost.body isEqual:@"Quote"], @"Clean original, translation and quoted text together");
        Check([post.body containsString:@"t.co"] && [post.quotedPost.body containsString:@"t.co"], @"Export cleanup never mutates the cached/native post");
        Check([cleaned.link isEqual:post.link], @"The dedicated original-link footer remains intact");
        NSLog(@"PASS: %lu short-link cleanup checks", (unsigned long)checks);
    }
    return 0;
}
