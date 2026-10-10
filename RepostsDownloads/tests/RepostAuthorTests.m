#import <Foundation/Foundation.h>
#import "../BHRDRepostAuthor.h"
#include <stdlib.h>
static NSUInteger checks;
static void Check(BOOL pass, NSString *name) {
    checks++; if (!pass) { NSLog(@"FAIL: %@", name); exit(1); }
}
static NSDictionary *Row(NSString *text, double x, double y, BOOL semantic) {
    return @{@"text": text, @"x": @(x), @"y": @(y), @"semantic": @(semantic)};
}
@interface HeaderTextModel : NSObject
@property(nonatomic, strong) id attributedString;
@end
@implementation HeaderTextModel @end
@interface HeaderLabel : NSObject
@property(nonatomic, strong) id textModel;
@end
@implementation HeaderLabel @end
int main(void) {
    @autoreleasepool {
        // The failed preview has no network/native model author. The only
        // available identity is the rendered host header, with independent media.
        NSDictionary *combined = BHRDSelectRepostAuthor(@[Row(@"🐟 🐟 @chitZZYYB · 4小时", 65, 28, YES)], nil);
        Check([combined[@"handle"] isEqual:@"chitZZYYB"], @"Read username from a rendered header with emoji and timestamp");
        Check([combined[@"name"] isEqual:@"🐟 🐟"], @"Keep the original display name and remove timestamp");
        NSArray *split = @[Row(@"已关注的人转推了", 65, 0, NO), Row(@"原作者", 65, 25, YES), Row(@"@original · 1小时", 120, 25, YES), Row(@"正文 @wrong", 65, 65, NO)];
        NSDictionary *author = BHRDSelectRepostAuthor(split, nil);
        Check([author[@"name"] isEqual:@"原作者"] && [author[@"handle"] isEqual:@"original"], @"Join separate name and username views without the repost context");
        Check([BHRDSelectRepostAuthor(@[Row(@"作者", 65, 20, YES), Row(@"@stacked", 65, 42, YES)], nil)[@"name"] isEqual:@"作者"], @"Handle a two-line author header");
        Check([BHRDSelectRepostAuthor(@[Row(@"鲲", 65, 20, YES), Row(@"@onechar", 100, 20, YES)], nil)[@"name"] isEqual:@"鲲"], @"Single-character display names are valid");
        Check([BHRDSelectRepostAuthor(@[Row(@"@handle_only", 65, 20, YES)], nil)[@"handle"] isEqual:@"handle_only"], @"A username alone is still usable");
        Check(BHRDSelectRepostAuthor(@[Row(@"@old_user", 65, 20, YES)], @"new_user") == nil, @"A reused or mismatched author header cannot supply another user's avatar");
        Check(BHRDSelectRepostAuthor(@[Row(@"@Original", 65, 20, YES)], @"original") != nil, @"Account matching is case-insensitive");
        for (NSString *invalid in @[@"回复 @wrong", @"Replying to @wrong", @"RT @wrong", @"@wrong 转推了", @"Someone reposted @wrong", @"某人转发 @wrong", @"@incomplete…", @"@abcdefghijklmnop", @"@one @two", @"正文\n@wrong", @"https://x.com/@wrong/path"]) {
            Check(BHRDSelectRepostAuthor(@[Row(invalid, 65, 20, YES)], nil) == nil, @"Reject context, truncated names, links and multiple/body mentions");
        }
        NSMutableDictionary *body = [Row(@"@body_mention", 65, 25, YES) mutableCopy]; body[@"body"] = @YES;
        Check(BHRDSelectRepostAuthor(@[body], nil) == nil, @"Explicit body text never supplies an author");
        Check(BHRDSelectRepostAuthor(@[Row(@"@quoted", 65, 160, YES)], nil) == nil, @"A lower embedded header cannot supply the main author");
        Check(BHRDSelectRepostAuthor(@[], nil) == nil, @"An unloaded header waits instead of inventing a name");
        NSString *nativeHandle = @"\u2066\u202A@narutomohamed93\u202C\u2069";
        NSDictionary *directional = BHRDSelectRepostAuthor(@[Row(@"魔都日常", 65, 12, YES), Row(nativeHandle, 65, 34, YES)], nil);
        Check([directional[@"name"] isEqual:@"魔都日常"] && [directional[@"handle"] isEqual:@"narutomohamed93"], @"Real X direction isolates do not hide both author lines");
        // Recorded through Apple's accessibility inspector on X 12.24.1.
        NSString *nativeCaption = [NSString stringWithFormat:@"魔都日常。 %@。 已验证, 按钮, 双击以查看个人资料。双击并按住以屏蔽用户或举报垃圾信息。", nativeHandle];
        NSMutableDictionary *accessible = [Row(nativeCaption, 65, 12, YES) mutableCopy]; accessible[@"accessibility"] = @YES;
        NSDictionary *native = BHRDSelectRepostAuthor(@[accessible], nil);
        Check([native[@"name"] isEqual:@"魔都日常"] && [native[@"handle"] isEqual:@"narutomohamed93"], @"Read the real X accessibility header without verification, role or hint text");
        Check(BHRDSelectRepostAuthor(@[accessible], @"different_user") == nil, @"Native accessibility metadata cannot override a different known author");
        accessible[@"semantic"] = @NO;
        Check(BHRDSelectRepostAuthor(@[accessible], nil) == nil, @"Localized metadata is only accepted inside an identified author header");
        accessible[@"semantic"] = @YES; accessible[@"accessibility"] = @NO;
        Check(BHRDSelectRepostAuthor(@[accessible], nil) == nil, @"Arbitrary visible text is not parsed as an accessibility author caption");
        accessible[@"accessibility"] = @YES;
        accessible[@"text"] = @"Writer. \u2066@writer\u2069. Verified, Button";
        Check([BHRDSelectRepostAuthor(@[accessible], nil)[@"name"] isEqual:@"Writer"], @"English accessibility punctuation is kept out of the display name");
        accessible[@"text"] = @"作者。 @truncated…";
        Check(BHRDSelectRepostAuthor(@[accessible], nil) == nil, @"Accessibility does not turn an ellipsized handle into a full username");
        accessible[@"text"] = @"作者。 @wrong。 谢谢你的回复";
        Check(BHRDSelectRepostAuthor(@[accessible], nil) == nil, @"Unrecognized prose after a handle is not verification metadata");
        NSDictionary *emoji = BHRDSelectRepostAuthor(@[Row(@"👩‍💻 \u2066@developer\u2069", 65, 12, YES)], nil);
        Check([emoji[@"name"] isEqual:@"👩‍💻"], @"Removing direction marks preserves emoji joiners in display names");
        HeaderTextModel *model = [HeaderTextModel new]; model.attributedString = [[NSAttributedString alloc] initWithString:@"作者 @native"];
        HeaderLabel *label = [HeaderLabel new]; label.textModel = model;
        Check([BHRDRepostHeaderText(label) isEqual:@"作者 @native"], @"Read nested native text models rather than only UILabel strings");
        label.textModel = label;
        Check(BHRDRepostHeaderText(label) == nil, @"A self-referential text wrapper terminates"); label.textModel = nil;
        Check(BHRDRepostHeaderText(NSNull.null) == nil && BHRDRepostHeaderText(@42) == nil, @"Malformed text fields are safe");
        NSLog(@"PASS: %lu native repost author checks", (unsigned long)checks);
    }
    return 0;
}
