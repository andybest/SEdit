import Foundation

let start = Date()
let ef = try EditorFile(filePath: "/Users/andybest/Desktop/test.xml")
print("Time: \(Date().timeIntervalSince(start))s")
