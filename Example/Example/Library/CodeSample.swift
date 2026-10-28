import Foundation
import Runestone
import RunestoneJavaScriptLanguage

enum CodeSample {
    enum Language: String {
        case javaScript
        case markdown

        var treeSitterLanguage: TreeSitterLanguage {
            switch self {
            case .javaScript:
                return .javaScript
            case .markdown:
                return .markdown
            }
        }
    }

    static var javaScriptFolding: String {
        """
        // Tap the gutter chevrons to fold functions, loops, and collections.
        class ReadingList {
            constructor() {
                this.books = [
                    { title: "The Hobbit", author: "J. R. R. Tolkien" },
                    { title: "A Wizard of Earthsea", author: "Ursula K. Le Guin" }
                ];
            }

            printBooks() {
                for (const book of this.books) {
                    if (book.title.length > 0) {
                        console.log(`${book.title} by ${book.author}`);
                    }
                }
            }
        }

        function main() {
            const list = new ReadingList();
            list.printBooks();
        }

        main();
        """
    }

    static var markdownFolding: String {
        """
        # A folding notebook

        Tap a chevron in the gutter to collapse a section or code block.
        The Code Folding setting is available in the ellipsis menu.

        ## Reading list

        A section includes its subsections until the next heading at the same level.

        ### Fiction

        - The Hobbit
        - A Wizard of Earthsea

        ### Nonfiction

        - The Design of Everyday Things
        - A Philosophy of Software Design

        ## A code example

        ```javascript
        function greet(name) {
            if (name.length > 0) {
                console.log(`Hello, ${name}!`);
            }
        }

        greet("Runestone");
        ```

        Another chapter
        ---------------

        Underline-style headings support folding too, including their underline.

        ### Notes

        Fold this child, then its parent. Its collapsed state is retained.

        # The end

        Search and Go to Line can reveal text inside collapsed sections.
        """
    }

    static var `default`: String {
        """
        /**
         * This is a Runestone text view with syntax highlighting
         * for the JavaScript programming language.
         */

        let names = ["Steve Jobs", "Tim Cook", "Eddy Cue"]
        let years = [1955, 1960, 1964]
        printNamesAndYears(names, years)

        // Print the year each person was born.
        function printNamesAndYears(names, years) {
          for (let i = 0; i < names.length; i++) {
            console.log(names[i] + " was born in " + years[i])
          }
        }
        """
    }
}

final class ExampleLanguageProvider: TreeSitterLanguageProvider {
    func treeSitterLanguage(named languageName: String) -> TreeSitterLanguage? {
        switch languageName.lowercased() {
        case "javascript", "js", "jsx":
            return .javaScript
        case "markdown_inline":
            return .markdownInline
        default:
            return nil
        }
    }
}
