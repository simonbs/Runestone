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
@end

@implementation ObjCLinePosition
- (instancetype)initWithLineNumber:(NSInteger)lineNumber column:(NSInteger)column {
    if (self = [super init]) {
        self.lineNumber = lineNumber;
        self.column = column;
    }
    return self;
}
@end
