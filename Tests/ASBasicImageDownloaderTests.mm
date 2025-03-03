//
//  ASBasicImageDownloaderTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#if !__has_include(<AsyncDisplayKit/AsyncDisplayKit.h>)
#import "ASBasicImageDownloader.h"
#else
#import <AsyncDisplayKit/ASBasicImageDownloader.h>
#endif

@interface ASBasicImageDownloaderTests : XCTestCase

@end

@implementation ASBasicImageDownloaderTests

- (void)testAsynchronouslyDownloadTheSameURLTwice
{
  XCTestExpectation *firstExpectation = [self expectationWithDescription:@"First ASBasicImageDownloader completion handler should be called within 3 seconds"];
  XCTestExpectation *secondExpectation = [self expectationWithDescription:@"Second ASBasicImageDownloader completion handler should be called within 3 seconds"];

  ASBasicImageDownloader *downloader = [ASBasicImageDownloader sharedImageDownloader];
  NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"logo-square"
                                                        withExtension:@"png"
                                                         subdirectory:@"TestResources"];

  [downloader downloadImageWithURL:URL
                       shouldRetry:YES
                     callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                  downloadProgress:nil
                        completion:^(id<ASImageContainerProtocol>  _Nullable image, NSError * _Nullable error, id  _Nullable downloadIdentifier, id _Nullable userInfo) {
                          [firstExpectation fulfill];
                        }];
  
  [downloader downloadImageWithURL:URL
                       shouldRetry:YES
                     callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                  downloadProgress:nil
                        completion:^(id<ASImageContainerProtocol>  _Nullable image, NSError * _Nullable error, id  _Nullable downloadIdentifier, id _Nullable userInfo) {
                          [secondExpectation fulfill];
                        }];

  [self waitForExpectationsWithTimeout:30 handler:nil];
}

@end
