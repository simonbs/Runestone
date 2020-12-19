//
//  EditorTextStorage.m
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

#import "EditorTextStorage.h"
@import RunestoneDocumentLineTree;
@import RunestoneHighlighter;

@interface EditorTextStorage () <LineManagerDelegate, HighlighterDelegate>
@end

@implementation EditorTextStorage {
    NSMutableAttributedString *_internalString;
    LineManager *_lineManager;
    Highlighter *_highlighter;
}

// MARK: - Lifecycle
- (instancetype)init {
    if (self = [super init]) {
        _internalString = [NSMutableAttributedString new];
        _highlighter = [[Highlighter alloc] initWithEncoding:HighlighterEncodingUtf8];
//        _parser.language = [[Language alloc] initWithLanguage:tree_sitter_javascript()];
        _highlighter.delegate = self;
        _lineManager = [LineManager new];
        _lineManager.delegate = self;
    }
    return self;
}

// MARK: - NSTextStorage
- (NSString *)string {
    return _internalString.string;
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [self beginEditing];
    [_highlighter markRangeEdited:range];
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
    [_highlighter processEditing];
    if ([self.editorDelegate respondsToSelector:@selector(editorTextStorageDidProcessEditing:)]) {
        [self.editorDelegate editorTextStorageDidProcessEditing:self];
    }
}

// MARK: - Public
- (NSInteger)lineCount {
    return _lineManager.lineCount;
}

- (ObjCLinePosition * _Nullable)positionOfCharacterAt:(NSInteger)location {
    LinePosition *linePosition = [_lineManager positionOfCharacterAtLocation:@(location)];
    if (linePosition != nil) {
        return [[ObjCLinePosition alloc] initWithLineNumber:linePosition.lineNumber column:linePosition.column length:linePosition.length];
    } else {
        return nil;
    }
}

- (NSInteger)locationOfLineWithLineNumber:(NSInteger)lineNumber {
    return [_lineManager locationOfLineWithLineNumber:@(lineNumber)];
}

- (NSString *)substringInRange:(NSRange)range {
    if (range.location + range.length <= _internalString.length) {
        return [_internalString attributedSubstringFromRange:range].string;
    } else {
        return nil;
    }
}

// MARK: - LineManagerDelegate
- (NSString * _Nonnull)lineManager:(LineManager * _Nonnull)lineManager characterAtLocation:(NSInteger)location {
    return [self.string substringWithRange:NSMakeRange(location, 1)];
}

- (void)lineManagerDidInsertLine:(LineManager * _Nonnull)lineManager {
    if ([self.editorDelegate respondsToSelector:@selector(editorTextStorageDidInsertLine:)]) {
        [self.editorDelegate editorTextStorageDidInsertLine:self];
    }
}

- (void)lineManagerDidRemoveLine:(LineManager * _Nonnull)lineManager {
    if ([self.editorDelegate respondsToSelector:@selector(editorTextStorageDidRemoveLine:)]) {
        [self.editorDelegate editorTextStorageDidRemoveLine:self];
    }
}

// MARK: - HighlighterDelegate
- (HighlighterLinePosition * _Nonnull)highlighter:(Highlighter * _Nonnull)highlighter linePositionAtLocation:(NSInteger)location {
    LinePosition *linePosition = [_lineManager positionOfCharacterAtLocation:@(location)];
    return [[HighlighterLinePosition alloc] initWithLineNumber:linePosition.lineNumber column:linePosition.column];
}

- (NSString * _Nullable)highlighter:(Highlighter * _Nonnull)highlighter substringAtLocation:(NSInteger)location { 
    return [self substringInRange:NSMakeRange(location, 1)];
}

@end
