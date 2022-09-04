# Getting Started

This articles gets you started using Runestone in your project.

## Installation

Runestone is distributed using the [Swift Package Manager](https://www.swift.org/package-manager/). Install it in a project by adding it as a dependency in your Package.swift manifest or through "Package Dependencies" in  project settings.

```swift
let package = Package(
    dependencies: [
        .package(url: "git@github.com:simonbs/Runestone.git", from: "0.1.0")
    ]
)
```

## Usage

The following steps describe how to add a <doc:TextView> to an app and start syntax highlighting text.

#### 1. Create a TextView

The <doc:TextView> is a subclass of UIScrollView and as such can be initialized like any other view. It has an API that is very similar to the one of UITextView.

```swift
let textView = TextView()
view.addSubView(textView)
```

The text view can be customized in a variety of ways. The following code snippet shows how to enable line numbers, show the selected line, add a page guide, show invisible characters and adjust the line-height. Refer to the documentation of <doc:TextView> for a full overview of the settings.

```swift
// Show line numbers.
textView.showLineNumbers = true
// Highlight the selected line.
textView.lineSelectionDisplayType = .line
// Show a page guide after the 80th character.
textView.showPageGuide = true
textView.pageGuideColumn = 80
// Show all invisible characters.
textView.showTabs = true
textView.showSpaces = true
textView.showLineBreaks = true
textView.showSoftLineBreaks = true
// Set the line-height to 130%
textView.lineHeightMultiplier = 1.3
```

#### 2. Add a language

To start using <doc:TextView> in an app, you should add the language of the text you would like to syntax highlight. Runestone uses [Tree-sitter](https://tree-sitter.github.io/tree-sitter/), and as such, Tree-sitter languages to syntax highlight text. Runestone does not come with any languages by default. Refer to the <doc:AddingATreeSitterLanguage> article for information on how to add a language to your app.

#### 3. Add a theme

The next step is to add a theme to your app. Runestone uses the <doc:Theme> protocol to customize the appearance of a <doc:TextView>. Refer to the <doc:CreatingATheme> article for information on how to add a theme to your app.

#### 4. Set the state of the text view

After adding a language and a theme to your app, you are ready to set the language and theme on the text view.

You can set the language, theme, and text on your text view using the appropriate getters on an instance of <doc:TextView>. However, setting the language or text is an expensive operation as it requires processing the visible part of the text. Therefore it is recommended that you initialise an instance of <doc:TextViewState> and pass it to the text view using <doc:TextView/setState(_:addUndoAction:)>, as instances of <doc:TextViewState> can be created on a background queue and do most of the heavy work without blocking the main thread.

Assuming you have added a language to your app using the [TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) packages, you can create an instance of <doc:TextViewState> as shown below. If you have manually added a language to your app, then refer to <doc:AddingATreeSitterLanguage> for information on how to set the state of your text view.

```swift
DispatchQueue.global(qos: .userInitiated).async {
    // Initialize of TextViewState on a background queue to due avoid blocking the main thread.
    let text = "let foo = \"Hello World\""
    let state = TextViewState(text: text, theme: ColorfulTheme(), language: .javaScript)
    DispatchQueue.main.async {
        // setState(_:) should be called on the main thread.
        textView.setState(state)
    }
}
```

> Note: The above code snippet is only meant as an example. Please take care when offloading work to a background queue and cancel work that is no longer needed.

#### 5. Next steps

At this point, you should have a fully functioning text view with support for syntax highlighting and other popular code editing features in your app.

You will likely want to set a delegate on your <doc:TextView> instance to handle text being edited. Take a look at the <doc:TextView/editorDelegate> property and the <doc:TextViewDelegate> to start responding to events sent by the text view.
