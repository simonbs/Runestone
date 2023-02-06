import Foundation

enum CodeSample {
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
