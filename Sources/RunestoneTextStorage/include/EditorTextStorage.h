//
//  EditorTextStorage.h
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

@import UIKit;

@class EditorTextStorage;

@protocol EditorTextStorageDelegate <NSObject>
- (void)editorTextStorage:(EditorTextStorage* _Nonnull)editorTextStorage didReplaceCharactersInRange:(NSRange)range withString:(NSString* _Nonnull)string;
- (void)editorTextStorageDidProcessEditing:(EditorTextStorage* _Nonnull)editorTextStorage;
@end

@interface EditorTextStorage: NSTextStorage
@property (nonatomic, weak) id<EditorTextStorageDelegate> _Nullable editorDelegate;
- (NSString* _Nullable)substringInRange:(NSRange)range;
@end
