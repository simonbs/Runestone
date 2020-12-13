//
//  File.m
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

#import "ObjCLinePosition.h"

@interface ObjCLinePosition ()
@property (nonatomic, assign) NSInteger lineNumber;
@property (nonatomic, assign) NSInteger column;
@property (nonatomic, assign) NSInteger length;
@end

@implementation ObjCLinePosition
- (instancetype)initWithLineNumber:(NSInteger)lineNumber column:(NSInteger)column length:(NSInteger)length {
    if (self = [super init]) {
        self.lineNumber = lineNumber;
        self.column = column;
        self.length = length;
    }
    return self;
}
@end
