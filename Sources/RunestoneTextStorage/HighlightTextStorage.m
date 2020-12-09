//
//  HighlightTextStorage.m
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

#import "HighlightTextStorage.h"
@import RunestoneDocumentLineTree;
@import TreeSitterBindings;
@import TreeSitterJSON;

@interface HighlightTextStorage () <LineManagerDelegate>
@end

@implementation HighlightTextStorage {
    NSMutableAttributedString *_internalString;
    LineManager *_lineManager;
    Parser *_parser;
}

// MARK: - Lifecycle

- (instancetype)init {
    if (self = [super init]) {
        _internalString = [NSMutableAttributedString new];
        _lineManager = [LineManager new];
        _lineManager.delegate = self;
        _parser = [Parser new];
        _parser.language = [[Language alloc] initWithLanguage:tree_sitter_json()];
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
    [_lineManager removeCharactersInRange:range];
    [_lineManager insertString:str inRange:range];
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
//    [_parser parse:self.string];
}

// MARK: - HighlightTextStorage

- (NSString * _Nonnull)lineManager:(LineManager * _Nonnull)lineManager characterAtLocation:(NSInteger)location {
    return [self.string substringWithRange:NSMakeRange(location, 1)];
}

@end
