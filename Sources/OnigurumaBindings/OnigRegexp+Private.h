//
//  Header.h
//  
//
//  Created by Simon Støvring on 30/11/2020.
//

#import <Foundation/Foundation.h>

@interface OnigRegexp (Private)
+ (OnigRegexp*)compile:(NSString*)expression;
+ (OnigRegexp*)compileIgnorecase:(NSString*)expression;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline;
+ (OnigRegexp*)compile:(NSString*)expression ignorecase:(BOOL)ignorecase multiline:(BOOL)multiline extended:(BOOL)extended;
+ (OnigRegexp*)compile:(NSString*)expression options:(OnigOption)options;
@end
