//
//  ASNetworkImageLoadInfo.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASNetworkImageLoadInfo.h"
#else
#import <AsyncDisplayKit/ASNetworkImageLoadInfo.h>
#endif

@implementation ASNetworkImageLoadInfo

- (instancetype)initWithURL:(NSURL *)url sourceType:(ASNetworkImageSourceType)sourceType downloadIdentifier:(id)downloadIdentifier userInfo:(id)userInfo
{
  if (self = [super init]) {
    _url = [url copy];
    _sourceType = sourceType;
    _downloadIdentifier = downloadIdentifier;
    _userInfo = userInfo;
  }
  return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  return self;
}

@end
