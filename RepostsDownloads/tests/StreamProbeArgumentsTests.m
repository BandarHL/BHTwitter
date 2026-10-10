#import "../BHRDStreamArguments.h"
static NSUInteger Checks;
static void Check(BOOL result,NSString *name) { Checks++; if (!result) { NSLog(@"FAIL: %@",name); exit(1); } }
int main(void) { @autoreleasepool {
    NSString *literal=@"https://video.twimg.com/amplify_video/123/pl/master.m3u8?tag=12&title=a%20b&literal=%27%24%28command%29";
    NSArray *args=BHRDStreamProbeArguments([NSURL URLWithString:literal]);
    Check([args.lastObject isEqual:literal],@"Network URL and query remain one exact argv element without shell interpretation");
    Check([args[[args indexOfObject:@"-rw_timeout"]+1] isEqual:@"15000000"],@"Probe uses a fifteen-second per-read timeout in protocol microseconds");
    Check([args containsObject:@"-show_streams"] && [args containsObject:@"-show_format"] && [args containsObject:@"json"],@"FFmpegKit receives compatible media information JSON for quality and audio selection");
    Check([args containsObject:@"-analyzeduration"] && [args containsObject:@"-probesize"],@"Probe input analysis work is bounded separately from the UI watchdog");
    Check(!BHRDStreamProbeArguments([NSURL fileURLWithPath:@"/tmp/cache"]) && !BHRDStreamProbeArguments([NSURL URLWithString:@"tav://custom/asset"]),@"Local caches and custom player schemes never enter a network probe");
    Check([BHRDStreamDiagnosticCategory(@"Connection timed out https://user:secret@example.invalid/private?token=secret") isEqual:@"network_timeout"],@"Error diagnosis preserves a fixed category without credentials or URLs");
    Check([BHRDStreamDiagnosticCategory(@"HTTP error 403 Forbidden private-user") isEqual:@"http_403"],@"HTTP denial has a useful fixed diagnostic category");
    Check([BHRDStreamDiagnosticCategory(@"unrecognized output /private/var/mobile/private-user") isEqual:@"unclassified_error_output"] && !BHRDStreamDiagnosticCategory(@""),@"Unknown errors do not copy private stderr content into logs");
    NSLog(@"PASS: %lu stream probe argument and diagnostic privacy checks",(unsigned long)Checks);
} return 0; }
