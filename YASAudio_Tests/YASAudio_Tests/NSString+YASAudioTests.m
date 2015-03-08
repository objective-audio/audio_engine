//
//  NSString+YASAudioTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "NSString+YASAudio.h"

@interface NSString_YASAudioTests : XCTestCase

@end

@implementation NSString_YASAudioTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testFileTypeStringWithHFSTypeCodeSuccess
{
    OSType fcc = 'abcd';
    NSString *fileType = [NSString yas_fileTypeStringWithHFSTypeCode:fcc];
    XCTAssertEqualObjects(fileType, @"'abcd'");
}

- (void)testFileTypeStringWithHFSTypeCodeZeroSuccess
{
    OSType fcc = 0;
    NSString *fileType = [NSString yas_fileTypeStringWithHFSTypeCode:fcc];
    XCTAssertEqualObjects(fileType, @"''");
}

- (void)testHFSTypeCodeSuccess
{
    NSString *fileType = @"'abcd'";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 'abcd');
}

- (void)testHFSTypeCodeIncludeQuoteSuccess
{
    NSString *fileType = @"'ab'c'";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 'ab\'c');
}

- (void)testHFSTypeCodeNoQuotesFail
{
    NSString *fileType = @"abcd";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 0);
}

- (void)testHFSTypeCodeGapQuotesFail
{
    NSString *fileType = @"'abc'd";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 0);
}

- (void)testHFSTypeCodeShortCharacterFail
{
    NSString *fileType = @"'abc'";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 0);
}

- (void)testHFSTypeCodeLongCharacterFail
{
    NSString *fileType = @"'abcde'";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 0);
}

- (void)testHFSTypeCodeJapaneseFail
{
    NSString *fileType = @"'あいうえ'";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 0);
}

- (void)testHFSTypeCodeEmojiFail
{
    NSString *fileType = @"'😊😓💦😱'";
    OSType fcc = [fileType yas_HFSTypeCode];
    XCTAssertEqual(fcc, 0);
}

- (void)testStringByAppendingLinePrefix
{
    NSString *string = @"abc\ndef\nghi";
    XCTAssertEqualObjects([string stringByAppendingLinePrefix:@"xyz"], @"xyzabc\nxyzdef\nxyzghi");
}

@end
