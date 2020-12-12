//
//  EditorTextStorage.h
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

@import UIKit;
#import "ObjCLinePosition.h"

@interface EditorTextStorage: NSTextStorage
- (ObjCLinePosition * _Nullable)linePositionAtLocation:(NSInteger)location __attribute__((swift_name("linePosition(at:)")));
@end
