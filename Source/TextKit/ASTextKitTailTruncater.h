//
//  ASTextKitTailTruncater.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASTextKitTruncating.h"
#else
#import <AsyncDisplayKit/ASTextKitTruncating.h>
#endif

#if AS_ENABLE_TEXTNODE

AS_SUBCLASSING_RESTRICTED
@interface ASTextKitTailTruncater : NSObject <ASTextKitTruncating>

@end

#endif
