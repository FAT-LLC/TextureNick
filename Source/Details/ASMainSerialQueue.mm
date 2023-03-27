//
//  ASMainSerialQueue.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASMainSerialQueue.h"
#else
#import <AsyncDisplayKit/ASMainSerialQueue.h>
#endif

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASThread.h"
#else
#import <AsyncDisplayKit/ASThread.h>
#endif
#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASInternalHelpers.h"
#else
#import <AsyncDisplayKit/ASInternalHelpers.h>
#endif
#import <queue>

@interface ASMainSerialQueue ()
{
  AS::Mutex _serialQueueLock;
  std::queue<dispatch_block_t> _blocks;
}

@end

@implementation ASMainSerialQueue

- (NSUInteger)numberOfScheduledBlocks
{
  AS::MutexLocker l(_serialQueueLock);
  return _blocks.size();
}

- (void)performBlockOnMainThread:(dispatch_block_t)block
{
  {
    AS::MutexLocker l(_serialQueueLock);
    _blocks.push(block);
  }

  [self runBlocks];
}

- (void)runBlocks
{
  dispatch_block_t mainThread = ^{
    AS::UniqueLock l(self->_serialQueueLock);
    do {
      if (self->_blocks.empty()) {
        break;
      }
      dispatch_block_t block = self->_blocks.front();
      self->_blocks.pop();
      {
        l.unlock();
        block();
        l.lock();
      }
    } while (true);
  };
  
  ASPerformBlockOnMainThread(mainThread);
}

- (NSString *)description
{
  NSString *desc = [super description];
  std::queue<dispatch_block_t> blocks = _blocks;
  [desc stringByAppendingString:@" Blocks: "];
  while (!blocks.empty()) {
      dispatch_block_t block = blocks.front();
      [desc stringByAppendingFormat:@"%@", block];
      blocks.pop();
  }
  return desc;
}

@end
