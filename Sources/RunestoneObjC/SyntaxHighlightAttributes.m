//
//  File.m
//  
//
//  Created by Simon Støvring on 31/12/2020.
//

#import "SyntaxHighlightAttributes.h"

@implementation SyntaxHighlightAttributes {
    NSRange _range;
    UIColor *_textColor;
    UIFont *_font;
}

- (instancetype)initWithRange:(NSRange)range textColor:(UIColor *)textColor font:(UIFont *)font {
    if (self = [super init]) {
        _range = range;
        _textColor = textColor;
        _font = font;
    }
    return self;
}

- (NSRange)range {
    return _range;
}

- (UIColor*)textColor {
    return _textColor;
}

- (UIFont*)font {
    return _font;
}
@end
