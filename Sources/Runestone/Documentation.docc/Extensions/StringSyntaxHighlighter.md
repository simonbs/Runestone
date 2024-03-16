# ``StringSyntaxHighlighter``

## Example

Create a syntax highlighter by passing a theme and language, and then call the ``StringSyntaxHighlighter/syntaxHighlight(_:)`` method to syntax highlight the provided text.

```swift
let syntaxHighlighter = StringSyntaxHighlighter(
    theme: TomorrowTheme(),
    language: .javaScript
)
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

## Topics

### Essentials

- <doc:SyntaxHighlightingAString>
- ``StringSyntaxHighlighter/syntaxHighlight(_:)``

### Initialing the Syntax Highlighter

- ``StringSyntaxHighlighter/init(theme:language:languageProvider:)``

### Configuring the Appearance

- ``StringSyntaxHighlighter/theme``
- ``StringSyntaxHighlighter/kern``
- ``StringSyntaxHighlighter/lineHeightMultiplier``
- ``StringSyntaxHighlighter/tabLength``

### Specifying the Language

- ``StringSyntaxHighlighter/language``
- ``StringSyntaxHighlighter/languageProvider``
