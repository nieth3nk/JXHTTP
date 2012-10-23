#import "JXOperation.h"

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@interface JXOperation ()
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
@property (assign) UIBackgroundTaskIdentifier backgroundTaskID;
#endif
@property (assign) BOOL isExecuting;
@property (assign) BOOL isFinished;
@end

@implementation JXOperation

@synthesize startsOnMainThread = _startsOnMainThread;
@synthesize continuesInAppBackground = _continuesInAppBackground;

#pragma mark -
#pragma mark Initialization

- (void)dealloc
{
    [self endAppBackgroundTask];
    
    [super dealloc];
}

- (id)init
{
    if ((self = [super init])) {
        #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
        self.backgroundTaskID = UIBackgroundTaskInvalid;
        #endif

        self.isExecuting = NO;
        self.isFinished = NO;
        self.startsOnMainThread = NO;
        self.continuesInAppBackground = NO;
    }
    return self;
}

+ (id)operation
{
    return [[[self alloc] init] autorelease];
}

#pragma mark -
#pragma mark NSOperation

- (void)start
{
    if (self.startsOnMainThread && ![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:YES];
        return;
    }
    
    if (!self.isReady || self.isCancelled || self.isExecuting || self.isFinished)
        return;
    
    [self willChangeValueForKey:@"isExecuting"];
    self.isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    @autoreleasepool {
        [self main];
    }
}

- (void)main
{
    NSAssert(NO, @"subclasses must implement and eventually call finish");
}

#pragma mark -
#pragma mark Public Methods

- (BOOL)isConcurrent
{
    return YES;
}

- (void)cancel
{
    [super cancel];
    [self finish];
}

- (void)finish
{
    if (self.isFinished)
        return;

    /**
     For reasons unknown, if the `start` method is never called then doing
     willChange/didChange for `isFinished` results in two unnerving behaviors:
     
     1. The log sometimes complains that "[the operation] went isFinished=YES
        without being started by the queue it is in"
     
     2. Especailly with multiple concurrent operations, a crash often occurs
        with `EXC_BAD_ACCESS` on `____NSOQschedule_block_invoke_0`
     
     Not setting `isFinished` at all prevents the operation from being removed
     from the queue and ultimately deallocated, so when an operation is
     cancelled we always `finish` it at the same time (see `cancel`).
     */
     
    if (self.isExecuting) {
        [self willChangeValueForKey:@"isExecuting"];
        [self willChangeValueForKey:@"isFinished"];
        self.isExecuting = NO;
        self.isFinished = YES;
        [self didChangeValueForKey:@"isExecuting"];
        [self didChangeValueForKey:@"isFinished"];
    } else {
        self.isExecuting = NO;
        self.isFinished = YES;
    }

    [self endAppBackgroundTask];
}

- (void)startAndWaitUntilFinished
{
    NSOperationQueue *tempQueue = [[NSOperationQueue alloc] init];
    [tempQueue addOperation:self];
    [tempQueue waitUntilAllOperationsAreFinished];
    [tempQueue release];
}

#pragma mark -
#pragma mark Accessors

- (void)setStartsOnMainThread:(BOOL)shouldStart
{
    if (self.isExecuting || self.isFinished)
        return;

    _startsOnMainThread = shouldStart;
}

- (void)setContinuesInAppBackground:(BOOL)shouldContinue
{
    _continuesInAppBackground = shouldContinue;

    if (self.continuesInAppBackground) {
        [self startAppBackgroundTask];
    } else {
        [self endAppBackgroundTask];
    }
}

#pragma mark -
#pragma mark Private Methods

- (void)startAppBackgroundTask
{
    #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
    
    if (self.backgroundTaskID != UIBackgroundTaskInvalid || self.isFinished)
        return;
    
    UIBackgroundTaskIdentifier taskID = UIBackgroundTaskInvalid;
    taskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:taskID];
    }];

    self.backgroundTaskID = taskID;
    
    #endif
}

- (void)endAppBackgroundTask
{
    #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_4_0
    
    if (self.backgroundTaskID == UIBackgroundTaskInvalid)
        return;

    [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskID];

    self.backgroundTaskID = UIBackgroundTaskInvalid;
    
    #endif
}

@end
