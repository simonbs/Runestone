//
//  DemoTextStorage.m
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

#import "DemoTextStorage.h"

@implementation DemoTextStorage {
    NSMutableAttributedString *_internalString;
}

- (instancetype)init {
    if (self = [super init]) {
        _internalString = [NSMutableAttributedString new];
    }
    return self;
}

- (NSString *)string {
    return _internalString.string;
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [self beginEditing];
    [_internalString replaceCharactersInRange:range withString:str];
    NSInteger length = (NSInteger)str.length - (NSInteger)range.length;
    [self edited:NSTextStorageEditedCharacters range:range changeInLength:length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
    [self beginEditing];
    [_internalString setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
    [self endEditing];
}

- (NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
    return [_internalString attributesAtIndex:location effectiveRange:range];
}

- (void)processEditing {
    [super processEditing];
    static NSRegularExpression *iExpression;
    NSString *pattern = @"i[\\p{Alphabetic}&&\\p{Uppercase}][\\p{Alphabetic}]+";
    iExpression = iExpression ?: [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    NSRange paragraphRange = [self.string paragraphRangeForRange:self.editedRange];
    [self removeAttribute:NSForegroundColorAttributeName range:paragraphRange];
    NSLog(@"%@", NSStringFromRange(paragraphRange));
    [iExpression enumerateMatchesInString:self.string options:0 range:paragraphRange usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        [self addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:result.range];
    }];
}

@end


