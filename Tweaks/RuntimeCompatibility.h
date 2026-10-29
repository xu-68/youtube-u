#import <Foundation/Foundation.h>

// Optional private UI state may disappear between YouTube releases.
// Catch only missing-key exceptions; unrelated failures must stay observable.
static inline id UYOptionalValueForKey(id object, NSString *key) {
    @try {
        return [object valueForKey:key];
    } @catch (NSException *exception) {
        if (![exception.name isEqualToString:NSUndefinedKeyException]) @throw;
        return nil;
    }
}
