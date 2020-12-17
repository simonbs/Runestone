//
//  EditorTextStorage.m
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

#import "EditorTextStorage.h"
@import RunestoneDocumentLineTree;
@import TreeSitterBindings;
@import TreeSitterJSON;

@interface EditorTextStorage () <LineManagerDelegate, ParserDelegate>
@end

@implementation EditorTextStorage {
    NSMutableAttributedString *_internalString;
    LineManager *_lineManager;
    Parser *_parser;
}

// MARK: - Lifecycle
- (instancetype)init {
    if (self = [super init]) {
        _internalString = [NSMutableAttributedString new];
        _parser = [[Parser alloc] initWithEncoding:SourceEncodingUtf8];
        _parser.language = [[Language alloc] initWithLanguage:tree_sitter_json()];
        _parser.delegate = self;
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
    InputEdit *inputEdit = [self inputEditForReplacingCharactersInRange:range];
    if (inputEdit != nil) {
        [_parser applyEdit:inputEdit];
    }
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

//    [_parser apply:]
    [_parser parse];

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

// MARK: - Private
- (InputEdit * _Nullable)inputEditForReplacingCharactersInRange:(NSRange)range {
    uint startByte = (uint)range.location;
    uint oldEndByte = (uint)range.location;
    uint newEndByte = (uint)range.location;
    if (range.length < 0) {
        oldEndByte += (uint)(range.length * -1);
    } else {
        newEndByte += (uint)range.length;
    }
    LinePosition *startLinePosition = [_lineManager positionOfCharacterAtLocation:@(startByte)];
    LinePosition *oldEndLinePosition = [_lineManager positionOfCharacterAtLocation:@(oldEndByte)];
    LinePosition *newEndLinePosition = [_lineManager positionOfCharacterAtLocation:@(newEndByte)];
    if (startLinePosition != nil && oldEndLinePosition != nil && newEndLinePosition != nil) {
        SourcePoint *startPoint = [[SourcePoint alloc] initWithRow:(uint)startLinePosition.lineNumber column:(uint)startLinePosition.column];
        SourcePoint *oldEndPoint = [[SourcePoint alloc] initWithRow:(uint)oldEndLinePosition.lineNumber column:(uint)oldEndLinePosition.column];
        SourcePoint *newEndPoint = [[SourcePoint alloc] initWithRow:(uint)newEndLinePosition.lineNumber column:(uint)newEndLinePosition.column];
        return [[InputEdit alloc] initWithStartByte:startByte
                                         oldEndByte:oldEndByte
                                         newEndByte:newEndByte
                                         startPoint:startPoint
                                        oldEndPoint:oldEndPoint
                                        newEndPoint:newEndPoint];
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

// MARK: - ParserDelegate
- (NSString *)parser:(Parser *)parser substringAtByteIndex:(uint)byteIndex point:(SourcePoint *)point {
    return [self substringInRange:NSMakeRange(byteIndex, 1)];
}

@end
