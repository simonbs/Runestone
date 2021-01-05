//
//  Header.h
//  
//
//  Created by Simon Støvring on 04/01/2021.
//

#import "UITextInputStringTokenizer+Swizzle.h"
#import <objc/runtime.h>

@implementation UITextInputStringTokenizer (Swizzle)
+ (void)load {
    static dispatch_once_t onceToken;
       dispatch_once(&onceToken, ^{
           Class class = [UITextInputStringTokenizer class];
           SEL originalSelector = @selector(rangeEnclosingPosition:withGranularity:inDirection:);
           SEL swizzledSelector = @selector(sbs_rangeEnclosingPosition:withGranularity:inDirection:);
           Method originalMethod = class_getInstanceMethod(class, originalSelector);
           Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
           BOOL didAddMethod =
               class_addMethod(class,
                   originalSelector,
                   method_getImplementation(swizzledMethod),
                   method_getTypeEncoding(swizzledMethod));
           if (didAddMethod) {
               class_replaceMethod(class,
                   swizzledSelector,
                   method_getImplementation(originalMethod),
                   method_getTypeEncoding(originalMethod));
           } else {
               method_exchangeImplementations(originalMethod, swizzledMethod);
           }
       });
}

- (UITextRange*)sbs_rangeEnclosingPosition:(UITextPosition*)position withGranularity:(UITextGranularity)granularity inDirection:(UITextDirection)direction {
    if (self.sbs_rangeEnclosingPositionReturnsNull) {
        return nil;
    } else {
        return [self sbs_rangeEnclosingPosition:position withGranularity:granularity inDirection:direction];
    }
}

- (void)setSbs_rangeEnclosingPositionReturnsNull:(BOOL)sbs_rangeEnclosingPositionReturnsNull {
    NSNumber *numberValue = [NSNumber numberWithBool:sbs_rangeEnclosingPositionReturnsNull];
     objc_setAssociatedObject(self, @selector(sbs_rangeEnclosingPositionReturnsNull), numberValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)sbs_rangeEnclosingPositionReturnsNull {
    NSNumber *numberValue = objc_getAssociatedObject(self, @selector(sbs_rangeEnclosingPositionReturnsNull));
    return [numberValue boolValue];
}
@end


