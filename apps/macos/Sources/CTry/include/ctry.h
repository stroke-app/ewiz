#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block` and returns the Objective-C exception it raised, or nil if it raised none.
///
/// Swift can't catch an Objective-C exception, and some framework calls report failure
/// with one (AVFAudio does). One that escapes a SwiftUI callback unwinds through SwiftUI's
/// update machinery, and from then on no button, `onChange` or `onAppear` in the process
/// runs again until it is relaunched. Wrap any such call made from SwiftUI in this.
NSException * _Nullable ewiz_try(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END
