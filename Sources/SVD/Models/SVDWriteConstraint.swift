//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift MMIO open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

public import XML

/// Define constraints for writing values to a field.
///
/// You can choose between three options, which are mutually exclusive.
public enum SVDWriteConstraint {
  /// If true, only the last read value can be written.
  case writeAsRead(SVDWriteConstraintWriteAsRead)
  /// If true, only the values listed in the enumeratedValues list can be
  /// written.
  case useEnumeratedValues(Bool)
  /// Contains the following two elements:
  /// - minimum: Specify the smallest number to be written to the field.
  /// - maximum: Specify the largest number to be written to the field.
  case range(SVDWriteConstraintRange)
}

extension SVDWriteConstraint: Decodable {}

extension SVDWriteConstraint: Encodable {}

extension SVDWriteConstraint: Equatable {}

extension SVDWriteConstraint: Hashable {}

extension SVDWriteConstraint: Sendable {}

extension SVDWriteConstraint: XMLElementInitializable {
  public init(_ element: borrowing XMLElement) throws {
    if let value = try? element.decode(
      SVDWriteConstraintWriteAsRead.self, fromChild: "writeAsRead")
    {
      self = .writeAsRead(value)
    } else if let value = try? element.decode(
      Bool.self, fromChild: "useEnumeratedValues")
    {
      self = .useEnumeratedValues(value)
    } else if let value = try? element.decode(
      SVDWriteConstraintRange.self, fromChild: "range")
    {
      self = .range(value)
    } else {
      throw XMLError.unknownElement(element.description)
    }
  }
}
