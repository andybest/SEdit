//
//  EditorError.swift
//  SEditPackageDescription
//
//  Created by Andy Best on 30/08/2017.
//

import Foundation

enum EditorError: Error {
    case unableToOpenFile(path: String)
    case general(msg: String)
}
