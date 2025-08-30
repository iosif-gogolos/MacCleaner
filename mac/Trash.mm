#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Provide a C-compatible wrapper

extern "C" bool mac_move_to_trash(const char* cpath) {
    @autoreleasepool {
        NSString *path = [NSString stringWithUTF8String:cpath];
        if (!path) return false;
        NSURL *url = [NSURL fileURLWithPath:path];
        NSError *error = nil;
        BOOL ok = [[NSFileManager defaultManager] trashItemAtURL:url resultingItemURL:nil error:&error];
        if (!ok) {
            NSLog(@"Failed to move %@ to trash: %@", path, error);
        }
        return ok;
    }
}
