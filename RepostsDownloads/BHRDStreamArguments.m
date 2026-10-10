#import "BHRDStreamArguments.h"
NSArray<NSString *> *BHRDStreamProbeArguments(NSURL *url) {
    if (!url.host.length || ![@[@"https",@"http"] containsObject:url.scheme.lowercaseString]) return nil;
    return @[@"-hide_banner",@"-v",@"error",@"-rw_timeout",@"15000000",@"-analyzeduration",@"5000000",@"-probesize",@"5000000",
        @"-show_streams",@"-show_format",@"-of",@"json",@"-i",url.absoluteString];
}
NSString *BHRDStreamDiagnosticCategory(NSString *message) {
    if (![message isKindOfClass:NSString.class] || !message.length) return nil;
    NSString *text=message.lowercaseString;
    for (NSArray *entry in @[@[@"connection timed out",@"network_timeout"],@[@"operation timed out",@"network_timeout"],@[@"failed to resolve",@"dns_failure"],
        @[@"name or service not known",@"dns_failure"],@[@"403 forbidden",@"http_403"],@[@"404 not found",@"http_404"],
        @[@"tls handshake",@"tls_failure"],@[@"ssl error",@"tls_failure"],@[@"certificate verify failed",@"tls_failure"],@[@"network is unreachable",@"network_unreachable"],
        @[@"connection refused",@"connection_refused"],@[@"invalid data found",@"invalid_media_data"],@[@"input/output error",@"io_failure"]])
        if ([text containsString:entry[0]]) return entry[1];
    return @"unclassified_error_output";
}
NSArray<NSString *> *BHRDStreamArguments(NSURL *url, NSNumber *index, NSURL *output) {
    if (!url || !output || !index || index.integerValue < 0) return nil;
    // FFprobe's stream index is carried unchanged from the selected menu item.
    // Preserve source codecs/bitrate rather than rescaling an automatically chosen variant.
    return @[@"-y", @"-rw_timeout", @"30000000", @"-i", url.absoluteString,
             @"-map", [NSString stringWithFormat:@"0:%@", index], @"-map", @"0:a:0?",
             @"-c", @"copy", @"-movflags", @"+faststart", output.path];
}
