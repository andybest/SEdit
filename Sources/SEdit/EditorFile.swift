//
//  EditorFile.swift
//  SEditPackageDescription
//
//  Created by Andy Best on 30/08/2017.
//

import Foundation

struct BufferIndex {
    let line: Int
    let character: Int
}

class EditorFile {
    var fileHandle: FileHandle?
    var buffer: BufferTree
    
    init(filePath path: String) throws {
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw EditorError.unableToOpenFile(path: path)
        }
        
        self.fileHandle = fileHandle
        self.buffer = BufferTree(fileHandle: fileHandle)
    }
}

class BufferTree {
    var rootNode: BufferNode
    
    init(rootNode: BufferNode) {
        self.rootNode = rootNode
    }
    
    convenience init(fileHandle: FileHandle) {
        fileHandle.seekToEndOfFile()
        let fileLength = fileHandle.offsetInFile
        fileHandle.seek(toFileOffset: 0)
        
        let reader = try! StreamReader(path: "/Users/andybest/Desktop/test.xml")
        
        var lineOffsets = [UInt64]()
        lineOffsets.reserveCapacity(1024)
        
        var offset = reader.offsetForNextLine()
        while offset != nil {
            // Process in chunks of 1024, with each chunk in its own autoreleasepool.
            // This is a tradeoff between speed and memory use.
            // Without the autoreleasepool, the memory usage is too high.
            autoreleasepool {
                for _ in 0..<1024 {
                    lineOffsets.append(offset!)
                    offset = reader.offsetForNextLine()
                    if offset == nil { break }
                }
            }
        }

        
        let leaf = BufferNode(value: FilePart(fileHandle: fileHandle, offset: 0, length: fileLength, lineOffsets: lineOffsets))
        let rootNode = BufferNode(leftChild: leaf, rightChild: nil)
        _ = rootNode.calculateWeight()
        
        let lineNode = rootNode.nodeWithLine(atIndex: 100)
        do {
            let l = try lineNode.value!.getLine(atIndex: 100)
            print(l)
        } catch {
            
        }
        
        self.init(rootNode: rootNode)
    }
    
    func character(atIndex index: BufferIndex) -> Character {
        return "."
    }
}

class BufferNode {
    var isLeaf = false
    var value: BufferPart?
    var weight: Int = 0
    
    init(leftChild: BufferNode, rightChild: BufferNode?) {
        isLeaf = false
        children = BufferChildren(left: leftChild, right: rightChild)
    }
    
    init(value: BufferPart) {
        self.value = value
        self.isLeaf = true
    }
    
    struct BufferChildren {
        var left: BufferNode
        var right: BufferNode?
    }
    
    var children: BufferChildren?
    
    func nodeWithLine(atIndex index: Int) -> BufferNode {
        if weight <= index {
            return children!.right!.nodeWithLine(atIndex: index - weight)
        } else {
            if isLeaf {
                return self
            } else {
                return children!.left.nodeWithLine(atIndex: index)
            }
        }
    }
    
    func calculateWeight() -> Int {
        if isLeaf {
            weight = value!.lineOffsets.count
            return weight
        } else {
            let leftWeight = children!.left.calculateWeight()
            weight = leftWeight
            
            if let right = children!.right {
                return leftWeight + right.calculateWeight()
            }
            
            return leftWeight
        }
    }
}

protocol BufferPart {
    var lineOffsets: [UInt64] { get set }
    var length: UInt64 { get }
    func getString(dataOffset: UInt64, length: UInt64) throws -> String
    func getLine(atIndex: Int) throws -> String
}

extension BufferPart {
    func getLine(atIndex index: Int) throws -> String {
        let lineOffset = lineOffsets[index]
        let lineLength: UInt64
        
        if index >= lineOffsets.count - 1 {
            lineLength = length - lineOffset
        } else {
            let nextLine = lineOffsets[index + 1]
            lineLength = nextLine - lineOffset
        }
        
        return try getString(dataOffset: lineOffset, length: lineLength)
    }
}

class FilePart: BufferPart {
    let fileHandle: FileHandle
    var lineOffsets: [UInt64]
    let offset: UInt64
    let length: UInt64
    
    init(fileHandle: FileHandle, offset: UInt64, length: UInt64, lineOffsets: [UInt64]) {
        self.fileHandle = fileHandle
        self.offset = offset
        self.length = length
        self.lineOffsets = lineOffsets
    }
    
    func getString(dataOffset: UInt64, length: UInt64) throws -> String {
        fileHandle.seek(toFileOffset: dataOffset + offset)
        let data = fileHandle.readData(ofLength: Int(length))
        
        guard let str = String(bytes: data, encoding: .utf8) else {
            throw EditorError.general(msg: "Unable to read line from file \(fileHandle)")
        }
        
        return str
    }
}

class StringPart: BufferPart {
    var length: UInt64 {
        return UInt64(string.characters.count)
    }
    
    var lineOffsets: [UInt64] = []
    var string: String = ""
    
    init() {
    }
    
    func calculateLineOffsets() {
        let lineDelimiter: Character = "\n"
    }
    
    func getString(dataOffset: UInt64, length: UInt64) throws -> String {
        let startIndex = string.index(string.startIndex, offsetBy: Int(dataOffset))
        let endIndex = string.index(startIndex, offsetBy: Int(length - 1))
        
        let sub = string[startIndex..<endIndex]
        return String(sub)
    }
}
