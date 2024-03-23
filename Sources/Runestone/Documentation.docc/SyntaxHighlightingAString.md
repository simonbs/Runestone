# Syntax Highlighting a String

Learn how to syntax hightlight a string without needing to create a TextView.

## Overview

The <doc:StringSyntaxHighlighter> can be used to syntax highlight a string without needing to create a <doc:TextView>.

Before reading this article, make sure that you have follow the guides on <doc:AddingATreeSitterLanguage> and <doc:CreatingATheme>.


## Creating an Attributed String

Create an instance of <doc:StringSyntaxHighlighter> by supplying the theme containing the colors and fonts to be used for syntax highlighting the text, as well as the language to use when parsing the text.

```swift
let syntaxHighlighter = StringSyntaxHighlighter(
    theme: TomorrowTheme(),
    language: .javaScript
)
```

If the language has any embedded languages, you will need to pass an object conforming to <doc:TreeSitterLanguageProvider>, which provides the syntax highlighter with additional languages.

Apply customizations to the syntax highlighter as needed.

```swift
syntaxHighlighter.kern = 0.3
syntaxHighlighter.lineHeightMultiplier = 1.2
syntaxHighlighter.tabLength = 2
```

With the syntax highlighter created and configured, we can syntax highlight the text.

```swift
let attributedString = syntaxHighlighter.syntaxHighlight(
  """
  function fibonacci(num) {
    if (num <= 1) {
      return 1
    }
    return fibonacci(num - 1) + fibonacci(num - 2)
  }
  """
)
```

The attributed string can be displayed using a UILabel or UITextView.
