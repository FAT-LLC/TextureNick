//
//  ASLayout+IGListDiffKit.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if AS_IG_LIST_DIFF_KIT
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASLayout.h"
#else
#import <AsyncDisplayKit/ASLayout.h>
#endif
#import <IGListDiffKit/IGListDiffKit.h>

@interface ASLayout(IGListDiffKit) <IGListDiffable>
@end
#endif // AS_IG_LIST_DIFF_KIT
