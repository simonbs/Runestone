//
//  ObjCLinePosition.h
//  
//
//  Created by Simon Støvring on 09/12/2020.
//

@import Foundation;

@interface ObjCLinePosition: NSObject
@property (nonatomic, readonly) NSInteger line;
@property (nonatomic, readonly) NSInteger column;
- (nonnull instancetype)initWithLine:(NSInteger)line column:(NSInteger)column;
@end
