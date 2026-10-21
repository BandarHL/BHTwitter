#import "BHRDTaskState.h"
@implementation BHRDTaskState {
    BOOL _cancelled;
    BOOL _finished;
    void (^_cancelHandler)(void);
}
- (BOOL)cancelled { @synchronized(self) { return _cancelled; } }
- (BOOL)finished { @synchronized(self) { return _finished; } }
- (void (^)(void))cancelHandler { @synchronized(self) { return [_cancelHandler copy]; } }
- (void)setCancelHandler:(void (^)(void))handler {
    BOOL invoke;
    @synchronized(self) {
        invoke = _cancelled;
        _cancelHandler = _finished ? nil : [handler copy];
    }
    if (invoke && handler) handler();
}
- (BOOL)finish {
    @synchronized(self) {
        if (_finished) return NO;
        _finished = YES;
        _cancelHandler = nil;
        return YES;
    }
}
- (BOOL)cancel {
    void (^handler)(void);
    @synchronized(self) {
        if (_finished) return NO;
        _finished = YES;
        _cancelled = YES;
        handler = _cancelHandler;
        _cancelHandler = nil;
    }
    if (handler) handler();
    return YES;
}
@end

static __weak id activeTransfer;
BOOL BHRDTryBeginTransfer(id owner) {
    @synchronized(BHRDTaskState.class) { if (activeTransfer && activeTransfer != owner) return NO; activeTransfer = owner; return YES; }
}
void BHRDEndTransfer(id owner) {
    @synchronized(BHRDTaskState.class) { if (activeTransfer == owner) activeTransfer = nil; }
}
