//
//  ASDispatch.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASDispatch.h"
#import "ASConfigurationInternal.h"
#else
#import <AsyncDisplayKit/ASDispatch.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>
#endif

// Prefer C atomics in this file because ObjC blocks can't capture C++ atomics well.
#import <stdatomic.h>

void ASDispatchApply(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, NS_NOESCAPE void(^work)(size_t i)) {
  if (threadCount == 0) {
    dispatch_apply(iterationCount, queue, work);
  } else {
    dispatch_group_t group = dispatch_group_create();
    __block atomic_size_t counter = ATOMIC_VAR_INIT(0);
    for (NSUInteger t = 0; t < threadCount; t++) {
      dispatch_group_async(group, queue, ^{
        size_t i;
        while ((i = atomic_fetch_add(&counter, 1)) < iterationCount) {
          work(i);
        }
      });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  }
};

void ASDispatchAsync(size_t iterationCount, dispatch_queue_t queue, NSUInteger threadCount, NS_NOESCAPE void(^work)(size_t i)) {
  if (threadCount == 0) {
    threadCount = NSProcessInfo.processInfo.activeProcessorCount * 2;
  }
  __block atomic_size_t counter = ATOMIC_VAR_INIT(0);
  for (NSUInteger t = 0; t < threadCount; t++) {
    dispatch_async(queue, ^{
      size_t i;
      while ((i = atomic_fetch_add(&counter, 1)) < iterationCount) {
        work(i);
      }
    });
  }
};

