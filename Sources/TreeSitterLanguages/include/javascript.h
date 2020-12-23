//
//  javascript.h
//  
//
//  Created by Simon Støvring on 17/12/2020.
//

#ifndef javascript_h
#define javascript_h

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TSLanguage TSLanguage;
const TSLanguage *tree_sitter_javascript(void);

#ifdef __cplusplus
}
#endif

#endif /* javascript_h */
