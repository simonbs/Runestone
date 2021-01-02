//
//  SyntaxHighlightAttributes.h
//  
//
//  Created by Simon Støvring on 31/12/2020.
//

@import UIKit;

@interface SyntaxHighlightAttributes: NSTextStorage
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) UIColor* _Nonnull textColor;
@property (nonatomic, readonly) UIFont* _Nonnull font;
- (instancetype _Nonnull)initWithRange:(NSRange)range textColor:(UIColor* _Nonnull)textColor font:(UIFont* _Nonnull)font;
@end
