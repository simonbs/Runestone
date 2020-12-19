//
//  EditorTextStorage.h
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

@import UIKit;
#import "ObjCLinePosition.h"

@class EditorTextStorage;

@protocol EditorTextStorageDelegate <NSObject>
@optional
- (void)editorTextStorageDidProcessEditing:(EditorTextStorage* _Nonnull)editorTextStorage;
@optional
- (void)editorTextStorageDidInsertLine:(EditorTextStorage* _Nonnull)editorTextStorage;
@optional
- (void)editorTextStorageDidRemoveLine:(EditorTextStorage* _Nonnull)editorTextStorage;
- (UIColor* _Nonnull)editorTextStorage:(EditorTextStorage* _Nonnull)editorTextStorage colorForCaptureName:(NSString* _Nonnull)captureName;
@end

@interface EditorTextStorage: NSTextStorage
@property (nonatomic, weak) id<EditorTextStorageDelegate> _Nullable editorDelegate;
@property (nonatomic, strong) UIColor* _Nullable textColor;
@property (nonatomic, readonly) NSInteger lineCount;
- (ObjCLinePosition * _Nullable)positionOfCharacterAt:(NSInteger)location
__attribute__((swift_name("positionOfLine(containingCharacterAt:)")));
- (NSInteger)locationOfLineWithLineNumber:(NSInteger)location
__attribute__((swift_name("locationOfLine(withLineNumber:)")));
- (NSString * _Nullable)substringInRange:(NSRange)range;
@end
