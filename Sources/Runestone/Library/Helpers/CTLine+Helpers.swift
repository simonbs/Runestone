import CoreText
import Foundation

extension CTLine {
   func isEmoji(atLocation location: Int) -> Bool {
       let runs = CTLineGetGlyphRuns(self) as? [CTRun] ?? []
       for run in runs {
           let runRange = CTRunGetStringRange(run)
           let lineRange = NSRange(location: runRange.location, length: runRange.length)
           if lineRange.contains(location) {
               return run.font?.familyName == ".Apple Color Emoji UI"
           }
       }
       return false
   }
}
