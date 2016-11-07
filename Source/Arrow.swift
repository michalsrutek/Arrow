//
//  Arrow.swift
//  Swift Structs Test
//
//  Created by Sacha Durand Saint Omer on 6/7/15.
//  Copyright (c) 2015 Sacha Durand Saint Omer. All rights reserved.
//

import Foundation
import CoreGraphics

/**
 This is the protocol that makes your swift Models JSON parsable.
 
 A typical implementation would be the following, preferably in an extension
 called `MyModel+JSON` to keep things nice and clean :
 
        //  MyModel+JSON.swift

        import Arrow

        extension MyModel: ArrowParsable {

            mutating func deserialize(json: JSON) {
                myVariable <-- json["jsonProperty"]
                //...
            }
        }
 */
public protocol ArrowParsable {
    /// Makes sur your models can be constructed with an empty constructor.
    init()
    /// The method you declare your json mapping in.
    mutating func deserialize(_ json: JSON)
}

/**
 This is a shortcut protocol to init your custom models with JSON.
 
 If the Model conforms to `ArrowParsable` protocol, to also make it initializable with JSON,
 just declare an extension like this:
 
        extension MyModel: ArrowInitializable {}
 */
public protocol ArrowInitializable {
    init(json: JSON)
}

extension ArrowInitializable where Self: ArrowParsable {
    public init(json: JSON) {
        self.init()
        self.deserialize(json)
    }
}

private let dateFormatter = DateFormatter()
private var useReferenceDate = false

/**
 This is used to configure NSDate parsing on a global scale.
 
        Arrow.setDateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        // or
        Arrow.setUseTimeIntervalSinceReferenceDate(true)
 
 
For more fine grained control, use `dateFormat` on a per field basis :
 
        createdAt <-- json["created_at"]?.dateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZZ")
 */
public class Arrow {
    /// Sets the defaut dateFormat for parsing NSDates.
    public class func setDateFormat(_ format: String) {
        dateFormatter.dateFormat = format
    }
    
    /**
     Sets `timeIntervalSinceReferenceDate` parsing as the default for NSDates parsing.
     
     Default is `false`
     
     For more information see `NSDate(timeIntervalSinceReferenceDate`
     documentation
     */
    public class func setUseTimeIntervalSinceReferenceDate(_ ref: Bool) {
        useReferenceDate = ref
    }
}

// MARK: - Parse Default swift Types

infix operator <--

public func <-- <T>(left: inout T, right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: parseType)
}

/// Parses optional default swift types.
public func <-- <T>(left: inout T?, right: JSON?) {
    parseType(&left, right: right)
}

/// Parses enums.
public func <-- <T: RawRepresentable>(left: inout T, right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses optional enums.
public func <-- <T: RawRepresentable>(left: inout T?, right: JSON?) {
    var temp: T.RawValue? = nil
    parseType(&temp, right:right)
    if let t = temp, let e = T.init(rawValue: t) {
        left = e
    }
}

/// Parses Array of enums.
public func <-- <T: RawRepresentable>(left: inout [T], right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses Optional Array of enums.
public func <-- <T: RawRepresentable>(left: inout [T]?, right: JSON?) {
    if let array = right?.data as? [T.RawValue] {
        left = array.map { T.init(rawValue: $0) }.flatMap {$0}
    }
}

/// Parses user defined custom types.
public func <-- <T: ArrowParsable>(left: inout T, right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses user defined optional custom types.
public func <-- <T: ArrowParsable>(left: inout T?, right: JSON?) {
    if let json = JSON(right?.data) {
        var t = T.init()
        t.deserialize(json)
        left = t
    }
}

/// Parses arrays of user defined custom types.
public func <-- <T: ArrowParsable>(left: inout [T], right: JSON?) {
    setLeftIfIsResultNonNil(left:&left, right:right, function: <--)
}

/// Parses optional arrays of user defined custom types.
public func <-- <T: ArrowParsable>(left: inout [T]?, right: JSON?) {
    if let a = right?.data as? [Any] {
        left = a.map {
            var t = T.init()
            if let json = JSON($0) {
                t.deserialize(json)
            }
            return t
        }
    }
}

/// Parses user defined custom types conforming to `RawRepresentable` protocol.
public func <-- <T: ArrowParsable & RawRepresentable>(left: inout T, right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses user defined optional custom types conforming to `RawRepresentable` protocol.
public func <-- <T: ArrowParsable & RawRepresentable>(left: inout T?, right: JSON?) {
    if let json = JSON(right?.data) {
        var t = T.init()
        t.deserialize(json)
        left = t
    }
}

/// Parses array of user defined custom types conforming to `RawRepresentable` protocol.
public func <-- <T: ArrowParsable & RawRepresentable>(left: inout [T], right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses array of user defined optional custom types conforming to `RawRepresentable` protocol.
public func <-- <T: ArrowParsable & RawRepresentable>(left: inout [T]?, right: JSON?) {
    if let a = right?.data as? [Any] {
        left = a.map {
            var t = T.init()
            if let json = JSON($0) {
                t.deserialize(json)
            }
            return t
        }
    }
}

/// Parses NSDates.
public func <-- (left: inout Date, right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses optional NSDates.
public func <-- (left: inout Date?, right: JSON?) {
    // Use custom date format over high level setting when provided
    if let customFormat = right?.jsonDateFormat, let s = right?.data as? String {
        let df = DateFormatter()
        df.dateFormat = customFormat
        left = df.date(from: s)
    } else if let s = right?.data as? String {
        if let date = dateFormatter.date(from: s) {
            left = date
        } else if let t = TimeInterval(s) {
            left = timeIntervalToDate(t)
        }
    } else if let t = right?.data as? TimeInterval {
        left = timeIntervalToDate(t)
    }
}

/// Parses NSURLs.
public func <-- (left: inout URL, right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses optional NSURLs.
public func <-- (left: inout URL?, right: JSON?) {
    var str = ""
    str <-- right
    let set = CharacterSet.urlQueryAllowed
    if let escapedStr = str.addingPercentEncoding(withAllowedCharacters: set),
        let url = URL(string:escapedStr) {
        left = url
    }
}

/// Parses arrays of plain swift types.
public func <-- <T>(left: inout [T], right: JSON?) {
    setLeftIfIsResultNonNil(left:&left, right:right, function: <--)
}

/// Parses optional arrays of plain swift types.
public func <-- <T>(left: inout [T]?, right: JSON?) {
    if let a = right?.data as? [Any] {
        let tmp: [T] = a.flatMap { var t: T?; parseType(&t, right: JSON($0)); return t }
        if tmp.count == a.count {
            left = tmp
        }
    }
}

/// Parses dictionaries of plain swift types.
public func <-- <K: Hashable, V>(left: inout [K: V], right: JSON?) {
    setLeftIfIsResultNonNil(left: &left, right: right, function: <--)
}

/// Parses optional dictionaries of plain swift types.
public func <-- <K: Hashable, V>(left: inout [K: V]?, right: JSON?) {
    if let d = right?.data as? [AnyHashable: Any] {
        var tmp: [K: V] = [:]
        d.forEach {
            var k: K?; parseType(&k, right: JSON($0))
            var v: V?; parseType(&v, right: JSON($1))
            if let k = k, let v = v { tmp[k] = v }
        }
        if tmp.count == d.count {
            left = tmp
        }
    }
}

// MARK: - Private methods.

func parseType<T>(_ left: inout T?, right: JSON?) {
    if let v: T = right?.data as? T {
        left = v
    } else if let s = right?.data as? String {
        parseString(&left, string:s)
    }
}

func parseString<T>(_ left: inout T?, string: String) {
    switch T.self {
    case is Int.Type: if let v = Int(string) { left = v as? T }
    case is UInt.Type: if let v = UInt(string) { left = v as? T }
    case is Double.Type: if let v = Double(string) { left = v as? T }
    case is Float.Type: if let v = Float(string) { left = v as? T }
    case is CGFloat.Type: if let v = CGFloat.NativeType(string) { left = CGFloat(v) as? T }
    case is Bool.Type: if let v = Int(string) { left = Bool(v != 0)  as? T}
    default:()
    }
}

func timeIntervalToDate(_ timeInterval: TimeInterval) -> Date {
    return useReferenceDate
    ? Date(timeIntervalSinceReferenceDate: timeInterval)
    : Date(timeIntervalSince1970: timeInterval)
}

func setLeftIfIsResultNonNil<T>(left: inout T, right: JSON?, function: (inout T?, JSON?) -> Void) {
    var temp: T? = nil
    function(&temp, right)
    if let t = temp {
        left = t
    }
}
