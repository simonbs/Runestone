//
//  File.m
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

#import "ObjCLinePosition.h"

@interface ObjCLinePosition ()
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, assign) NSInteger column;
@end

@implementation ObjCLinePosition
- (instancetype)initWithLine:(NSInteger)line column:(NSInteger)column {
    if (self = [super init]) {
        self.line = line;
        self.column = column;
    }
    return self;
}
@end
