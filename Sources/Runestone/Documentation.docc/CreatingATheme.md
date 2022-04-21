# Creating a Theme

Learn how to create a theme and customize the appearance of TextView.

## Overview

The <doc:Theme> protocol can be used to customize the appearance of <doc:TextView>. Runestone does not include any themes by default. However, you can find examples of themes [in the example project](https://github.com/simonbs/Runestone/tree/main/Example/Example/Themes) that is included in Runestone's repository on GitHub.

Take a look at the documentation of the <doc:Theme> protocol to get an overview of what aspects of <doc:TextView> can be customized.

## Syntax Highlighting Text

The theme determines the text styling and colors to use when syntax highlighting text. Implement the following methods on <doc:Theme> to specify the text styling and color of syntax highlighted text.

- <doc:Theme/font(for:)-6u3z2>
- <doc:Theme/fontTraits(for:)-38bfk>
- <doc:Theme/textColor(for:)>

The functions should return a font, font traits, and a color for a _highlight name_ which corresponds to a name specified in a Tree-sitter highlights query. For more information on Tree-sitter highlight queries, please refer to <doc:AddingATreeSitterLanguage>.

Highlight names are strings defined by the highlights query in the parser, and as such, there is no fixed set of highlight names used by Runestone. Consult the highlights query of the language you are using. This query is typically in a file named highlights.scm.

Examples of highlight names include `keyword`, `comment`, `string` and `function`. Highlight names can share common subsequences. Examples:

- `variable and `variable.parameter`.
- `function`, `function.builtin` and `function.method`.

Styling should be determined based on the longest matching highlight name. So for example `function.builtin` should be preferred over `function` but if `function.builtin` is not defined by your theme, it should fall back to `function`. The Swift code below contains an example of how we this logic can be implemented.

```swift
func findLongestMatch(highlightName: String) -> String? {
    // Split the highlight name on dots so "function.builtin.static" becomes ["function", "builtin", "static"]
    var components = highlightName.components(separatedBy: ".")
    // Loop through components to find the longest match.
    while !components.isEmpty {
        // Join all components with a dot so ["function", "builtin", "static"] becomes "function.builtin.static"
        let candidate = components.joined(separator: ".")
        if supportedHighlightNames.contains(candidate) {
            // The candidate highlight name is supported.
            return candidate
        } else {
            // Remove the last component so our next candidate will be one component shorter in the next iteration of the loop.
            components.removeLast()
        }
    }
    // No match found for the highlight name.
    return nil
}
```

The list below contains highlight names that are commonly used across a suite of languages. They might serve as a starting point for your theme.

- `attribute`
- `constant`
- `constant.builtin`
- `constructor`
- `comment`
- `delimiter`
- `escape`
- `field`
- `function`
- `function.builtin`
- `function.method`
- `keyword`
- `number`
- `operator`
- `property`
- `punctuation.bracket`
- `punctuation.delimiter`
- `punctuation.special`
- `string`
- `string.special`
- `tag`
- `type`
- `type.builtin`
- `variable`
- `variable.builtin`
