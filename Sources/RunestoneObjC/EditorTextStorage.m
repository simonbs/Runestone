//
//  EditorTextStorage.m
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

#import "EditorTextStorage.h"

@implementation EditorTextStorage {
    NSTextStorage *_internalString;
}

// MARK: - Lifecycle
- (instancetype)init {
    if (self = [super init]) {
        _internalString = [NSTextStorage new];
    }
    return self;
}

// MARK: - NSTextStorage
- (NSString *)string {
    return _internalString.string;
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [self beginEditing];
    NSInteger length = (NSInteger)str.length - (NSInteger)range.length;
    [_internalString replaceCharactersInRange:range withString:str];
    if ([self.editorDelegate respondsToSelector:@selector(editorTextStorage:didReplaceCharactersInRange:withString:)]) {
        [self.editorDelegate editorTextStorage:self didReplaceCharactersInRange:range withString:str];
    }
    [self edited:NSTextStorageEditedCharacters range:range changeInLength:length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
    [_internalString setAttributes:attrs range:range];
}

- (NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
    return [_internalString attributesAtIndex:location effectiveRange:range];
}

- (void)processEditing {
    [super processEditing];
    if ([self.editorDelegate respondsToSelector:@selector(editorTextStorageDidProcessEditing:)]) {
        [self.editorDelegate editorTextStorageDidProcessEditing:self];
    }
}

// MARK: - Public
- (NSString *)substringInRange:(NSRange)range {
    if (range.location + range.length <= _internalString.length) {
        return [_internalString.string substringWithRange:range];
    } else {
        return nil;
    }
}

@end
