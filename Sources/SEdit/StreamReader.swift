//
//  StreamReader.swift
//  SEditPackageDescription
//
//  Created by Andy Best on 30/08/2017.
//

import Foundation

class StreamReader {
    let encoding: String.Encoding
    let chunkSize: Int
    let fileHandle: FileHandle
    let delimiterBytes: Data
    let buffer: NSMutableData
    
    var atEof: Bool = false
    
    init(path: String, delimiter: String = "\n", encoding: String.Encoding = .utf8, chunkSize: Int = 4096) throws {
        self.encoding = encoding
        self.chunkSize = chunkSize
        
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw EditorError.unableToOpenFile(path: path)
        }
        
        self.fileHandle = fileHandle
        
        guard let delimiterBytes = delimiter.data(using: encoding) else {
            throw EditorError.general(msg: "Unable to create delimiter in the given encoding")
        }
        
        self.delimiterBytes = delimiterBytes
        
        guard let buffer = NSMutableData(capacity: chunkSize) else {
            throw EditorError.general(msg: "Unable to allocate file reading buffer")
        }
        
        self.buffer = buffer
    }
    
    func offsetForNextLine() -> UInt64? {
        if atEof { return nil }
        
        var range = buffer.range(of: delimiterBytes, options: [], in: NSMakeRange(0, buffer.length))
        
        while range.location == NSNotFound {
            let tmpData = fileHandle.readData(ofLength: chunkSize)
            
            if tmpData.count == 0 {
                atEof = true
                return nil
            }
            
            buffer.append(tmpData)
            range = buffer.range(of: delimiterBytes, options: [], in: NSMakeRange(0, buffer.length))
        }
        
        let lineStart = fileHandle.offsetInFile - UInt64(buffer.length)
        
        // Erase line from buffer
        buffer.replaceBytes(in: NSMakeRange(0, range.location + range.length), withBytes: nil, length: 0)
        
        return lineStart
    }
    
    deinit {
        closeFile()
    }
    
    func rewind() {
        fileHandle.seek(toFileOffset: 0)
        buffer.length = 0
        atEof = false
    }
    
    func closeFile() {
        fileHandle.closeFile()
    }
}
