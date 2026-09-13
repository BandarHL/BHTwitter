#import "BHRDStreamArguments.h"
NSArray<NSString *> *BHRDStreamArguments(NSURL *url, NSNumber *index, NSURL *output) {
    if (!url || !output || !index || index.integerValue < 0) return nil;
    // FFprobe's stream index is carried unchanged from the selected menu item.
    // Preserve source codecs/bitrate rather than rescaling an automatically chosen variant.
    return @[@"-y", @"-rw_timeout", @"30000000", @"-i", url.absoluteString,
             @"-map", [NSString stringWithFormat:@"0:%@", index], @"-map", @"0:a:0?",
             @"-c", @"copy", @"-movflags", @"+faststart", output.path];
}
