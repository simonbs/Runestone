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
- (void)editorTextStorageDidProcessEditing:(EditorTextStorage* _Nonnull)editorTextStorage;
@end

@interface EditorTextStorage: NSTextStorage
@property (nonatomic, weak) id<EditorTextStorageDelegate> _Nullable editorDelegate;
@property (nonatomic, readonly) NSInteger lineCount;
- (ObjCLinePosition * _Nullable)linePositionAtLocation:(NSInteger)location __attribute__((swift_name("linePosition(at:)")));
- (NSString * _Nonnull)substringWithRange:(NSRange)range;
@end
