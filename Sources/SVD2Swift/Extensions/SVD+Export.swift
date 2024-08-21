//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift MMIO open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import SVD

let fileHeader = """
  // Generated by svd2swift.

  import MMIO\n\n
  """

struct ExportOptions {
  var indentation: Indentation
  var accessLevel: AccessLevel?
  var selectedPeripherals: [String]
  var namespaceUnderDevice: Bool
  var instanceMemberPeripherals: Bool
  var overrideDeviceName: String?
}

struct ExportContext {
  var outputWriter: OutputWriter
  var accessLevel: AccessLevel?
  var selectedPeripherals: [String]
  var namespaceUnderDevice: Bool
  var instanceMemberPeripherals: Bool
  var overrideDeviceName: String?
}

extension SVDDevice {
  func export(
    with options: ExportOptions,
    to output: inout Output
  ) throws {
    var context = ExportContext(
      outputWriter: .init(output: output, indentation: options.indentation),
      accessLevel: options.accessLevel,
      selectedPeripherals: options.selectedPeripherals,
      namespaceUnderDevice: options.namespaceUnderDevice,
      instanceMemberPeripherals: options.instanceMemberPeripherals,
      overrideDeviceName: options.overrideDeviceName)
    defer { output = context.outputWriter.output }
    try self.export(context: &context)
  }

  fileprivate func export(
    context: inout ExportContext
  ) throws {
    var outputPeripherals = [SVDPeripheral]()
    if context.selectedPeripherals.isEmpty {
      outputPeripherals = self.peripherals.peripheral
    } else {
      var peripheralsByName = [String: SVDPeripheral]()
      for peripheral in self.peripherals.peripheral {
        peripheralsByName[peripheral.name] = peripheral
      }
      for selectedPeripheral in context.selectedPeripherals {
        guard let peripheral = peripheralsByName[selectedPeripheral] else {
          throw SVD2SwiftError.unknownPeripheral(
            selectedPeripheral, self.peripherals.peripheral.map(\.name))
        }
        outputPeripherals.append(peripheral)
      }
    }
    outputPeripherals = outputPeripherals.sorted { $0.name < $1.name }

    let deviceName = context.overrideDeviceName ?? self.swiftName
    context.outputWriter.append(fileHeader)
    if context.namespaceUnderDevice {
      let deviceDeclarationType =
        if context.instanceMemberPeripherals {
          "struct"
        } else {
          "enum"
        }
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        \(context.accessLevel)\(deviceDeclarationType) \(deviceName) {

        """)
      context.outputWriter.indent()
    }
    for (index, peripheral) in outputPeripherals.enumerated() {
      peripheral.exportAccessor(
        context: &context,
        registerProperties: registerProperties)
      if index < outputPeripherals.count - 1 {
        context.outputWriter.append("\n")
      }
    }
    if context.namespaceUnderDevice {
      context.outputWriter.outdent()
      context.outputWriter.append("}\n")
    }
    try context.outputWriter.writeOutput(to: "Device.swift")

    for peripheral in outputPeripherals {
      context.outputWriter.append(fileHeader)

      var parentTypes = [String]()
      if context.namespaceUnderDevice {
        parentTypes.append(deviceName)
      }

      var exportQueue = [([any SVDExportable], [String], SVDRegisterProperties)]()
      exportQueue.append(([peripheral], parentTypes, self.registerProperties))

      // Track indices instead of popping front to avoid O(N) pop.
      var currentIndex = exportQueue.startIndex
      while currentIndex < exportQueue.endIndex {
        defer { exportQueue.formIndex(after: &currentIndex) }
        if currentIndex != exportQueue.startIndex {
          context.outputWriter.append("\n")
        }
        let (elements, parentTypes, registerProperties) = exportQueue[currentIndex]
        if !parentTypes.isEmpty {
          let parentTypeFullName = parentTypes.joined(separator: ".")
          context.outputWriter.append("extension \(parentTypeFullName) {\n")
          context.outputWriter.indent()
        }

        for (index, element) in elements.enumerated() {
          let (exports, registerProperties) = element.exportType(
            context: &context,
            registerProperties: registerProperties)
          if !exports.isEmpty {
            exportQueue.append(
              (
                exports,
                parentTypes + [element.swiftName],
                registerProperties
              ))
          }
          if index < elements.count - 1 {
            context.outputWriter.append("\n")
          }
        }

        if !parentTypes.isEmpty {
          context.outputWriter.outdent()
          context.outputWriter.append("}\n")
        }
      }
      try context.outputWriter.writeOutput(to: "\(peripheral.swiftName).swift")
    }
  }
}

protocol SVDExportable {
  var swiftName: String { get }

  func exportType(
    context: inout ExportContext,
    registerProperties: SVDRegisterProperties
  ) -> ([any SVDExportable], SVDRegisterProperties)

  func exportAccessor(
    context: inout ExportContext,
    registerProperties: consuming SVDRegisterProperties)
}

extension SVDPeripheral: SVDExportable {
  func exportType(
    context: inout ExportContext,
    registerProperties: SVDRegisterProperties
  ) -> ([any SVDExportable], SVDRegisterProperties) {
    let typeName = self.swiftName
    let registerProperties = self.registerProperties.merging(registerProperties)

    var exports = [any SVDExportable]()
    if let derivedFrom = self.derivedFrom {
      // FIXME: Handle only exporting B where B deriveFrom A
      context.outputWriter.append("\(context.accessLevel)typealias \(typeName) = \(derivedFrom)\n")
    } else {
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @RegisterBlock
        \(context.accessLevel)struct \(typeName) {

        """)
      context.outputWriter.indent()
      if let registersAndClusters = self.registers {
        let registers = registersAndClusters.register
        let clusters = registersAndClusters.cluster

        for (index, register) in registers.enumerated() {
          register.exportAccessor(
            context: &context,
            registerProperties: registerProperties)
          exports.append(register)
          if index < registers.count - 1 {
            context.outputWriter.append("\n")
          }
        }

        if !registers.isEmpty, !clusters.isEmpty {
          context.outputWriter.append("\n")
        }

        for (index, cluster) in clusters.enumerated() {
          cluster.exportAccessor(
            context: &context,
            registerProperties: registerProperties)
          exports.append(cluster)
          if index < clusters.count - 1 {
            context.outputWriter.append("\n")
          }
        }
      }
      context.outputWriter.outdent()
      context.outputWriter.append("}\n")
    }
    return (exports, registerProperties)
  }

  func exportAccessor(
    context: inout ExportContext,
    registerProperties: consuming SVDRegisterProperties
  ) {
    let typeName = self.swiftName
    let instanceName = typeName.lowercased()

    let registerProperties = self.registerProperties.merging(registerProperties)

    let accessorModifier =
      if context.namespaceUnderDevice && !context.instanceMemberPeripherals {
        "static "
      } else {
        ""
      }

    if let count = self.dimensionElement.dim {
      // FIXME: properties.size may be incorrect here.
      let stride = self.dimensionElement.dimIncrement ?? registerProperties.size
      guard let stride = stride else {
        // FIXME: warning diagnostic
        print("warning: skipped exporting \(instanceName): unknown stride")
        return
      }
      for index in 0..<count {
        let addressOffset = stride * index
        context.outputWriter.append(
          """
          \(comment: self.swiftDescription)
          \(context.accessLevel)\(accessorModifier)let \(identifier: "\(instanceName)\(index)") = \(typeName)(unsafeAddress: \(hex: self.baseAddress + addressOffset))

          """)
        if index < count - 1 {
          context.outputWriter.append("\n")
        }
      }
    } else {
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        \(context.accessLevel)\(accessorModifier)let \(identifier: instanceName) = \(typeName)(unsafeAddress: \(hex: self.baseAddress))

        """)
    }
  }
}

extension SVDCluster: SVDExportable {
  func exportAccessor(
    context: inout ExportContext,
    registerProperties: SVDRegisterProperties
  ) {
    let typeName = self.swiftName
    let instanceName = typeName.lowercased()

    let registerProperties = self.registerProperties.merging(registerProperties)

    if let count = self.dimensionElement.dim {
      // FIXME: properties.size may be incorrect here.
      let stride = self.dimensionElement.dimIncrement ?? registerProperties.size
      guard let stride = stride else {
        // FIXME: warning diagnostic
        print("warning: skipped exporting \(instanceName): unknown stride")
        return
      }

      for index in 0..<count {
        let addressOffset = self.addressOffset + (stride * index)
        context.outputWriter.append(
          """
          \(comment: self.swiftDescription)
          @RegisterBlock(offset: \(hex: addressOffset))
          \(context.accessLevel)var \(identifier: "\(instanceName)\(index)"): \(typeName)

          """)
        if index < count - 1 {
          context.outputWriter.append("\n")
        }
      }
    } else {
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @RegisterBlock(offset: \(hex: self.addressOffset))
        \(context.accessLevel)var \(identifier: instanceName): \(typeName)

        """)
    }
  }

  func exportType(
    context: inout ExportContext,
    registerProperties: SVD.SVDRegisterProperties
  ) -> ([any SVDExportable], SVDRegisterProperties) {
    let registerProperties = self.registerProperties.merging(registerProperties)
    var exports = [any SVDExportable]()

    if let derivedFrom = self.derivedFrom {
      context.outputWriter.append("\(context.accessLevel)typealias \(self.swiftName) = \(derivedFrom)\n")
    } else {

      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @RegisterBlock
        \(context.accessLevel)struct \(self.swiftName) {

        """)
      context.outputWriter.indent()
      if let registers = self.register {
        for (index, register) in registers.enumerated() {
          register.exportAccessor(
            context: &context,
            registerProperties: registerProperties)
          exports.append(register)
          if index < registers.count - 1 {
            context.outputWriter.append("\n")
          }
        }
      }

      if !(self.register ?? []).isEmpty, !(self.cluster ?? []).isEmpty {
        context.outputWriter.append("\n")
      }

      if let clusters = self.cluster {
        for (index, cluster) in clusters.enumerated() {
          cluster.exportAccessor(
            context: &context,
            registerProperties: registerProperties)
          exports.append(cluster)
          if index < clusters.count - 1 {
            context.outputWriter.append("\n")
          }
        }
      }
      context.outputWriter.outdent()
      context.outputWriter.append("}\n")
    }
    return (exports, registerProperties)
  }
}

extension SVDRegister: SVDExportable {
  func exportAccessor(
    context: inout ExportContext,
    registerProperties: SVDRegisterProperties
  ) {
    let typeName = self.swiftName
    let instanceName = typeName.lowercased()

    let registerProperties = self.registerProperties.merging(registerProperties)

    if let count = self.dimensionElement.dim {
      // FIXME: properties.size may be incorrect here.
      let stride = self.dimensionElement.dimIncrement ?? registerProperties.size
      guard let stride = stride else {
        // FIXME: warning diagnostic
        print("warning: skipped exporting \(instanceName): unknown stride")
        return
      }
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @RegisterBlock(offset: \(hex: self.addressOffset), stride: \(hex: stride), count: \(count))
        \(context.accessLevel)var \(identifier: instanceName): RegisterArray<\(typeName)>

        """)
    } else {
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @RegisterBlock(offset: \(hex: self.addressOffset))
        \(context.accessLevel)var \(identifier: instanceName): Register<\(typeName)>

        """)
    }
  }

  func exportType(
    context: inout ExportContext,
    registerProperties: SVD.SVDRegisterProperties
  ) -> ([any SVDExportable], SVDRegisterProperties) {
    let registerProperties = self.registerProperties.merging(registerProperties)

    if let size = registerProperties.size {
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @Register(bitWidth: \(size))
        \(context.accessLevel)struct \(self.swiftName) {

        """)
      context.outputWriter.indent()
      let fields = self.fields?.field ?? []
      for (index, field) in fields.enumerated() {
        field.exportAccessor(
          context: &context,
          register: self,
          registerProperties: registerProperties)
        if index < fields.count - 1 {
          context.outputWriter.append("\n")
        }
      }
      context.outputWriter.outdent()
      context.outputWriter.append("}\n")
    } else {
      // FIXME: warning diagnostic
      print("warning: skipped exporting \(self.swiftName): unknown register size")
    }
    return ([], registerProperties)
  }
}

extension SVDField {
  func svd2SwiftName(register: SVDRegister) -> String {
    // Remove unsafe characters from the name.
    var name = self.swiftName

    // If the name of this field is the same as the parent register, suffix the
    // field name with "_FIELD". This is based on the **assumption** that no
    // other field in the register already has the new name.
    if name == register.swiftName {
      name += "_FIELD"
    }

    // If the field's name is all lowercase then the generated type and
    // property will collide. In this case we uppercase the name of the field to
    // avoid the collision.
    if name == name.lowercased() {
      name = name.uppercased()
    }

    return name
  }

  fileprivate func exportAccessor(
    context: inout ExportContext,
    register: SVDRegister,
    registerProperties: SVDRegisterProperties
  ) {
    let typeName = self.svd2SwiftName(register: register)
    let instanceName = typeName.lowercased()

    let macro =
      switch self.access ?? registerProperties.access {
      case .readOnly: "ReadOnly"
      case .writeOnly: "WriteOnly"
      case .readWrite: "ReadWrite"
      // FIXME: How to express in Swift?
      case .writeOnce: "WriteOnly"
      // FIXME: How to express in Swift?
      case .readWriteOnce: "ReadWrite"
      // FIXME: emit diagnostic about unknown -> reserved
      case nil: "Reserved"
      }

    let range = self.bitRange.range
    if let count = self.dimensionElement.dim {
      let stride = self.dimensionElement.dimIncrement ?? UInt64(range.count)
      // FIXME: array fields
      // Instead of splatting out N copies of the field we should have some way
      // to describe an array like RegisterArray
      for index in 0..<count {
        let bitOffset = stride * index
        context.outputWriter.append(
          """
          \(comment: self.swiftDescription)
          @\(macro)(bits: \(range.lowerBound + bitOffset)..<\(range.upperBound + bitOffset))
          \(context.accessLevel)var \(identifier: "\(instanceName)\(index)"): \(typeName)\(index)

          """)
        if index < count - 1 {
          context.outputWriter.append("\n")
        }
      }
    } else {
      context.outputWriter.append(
        """
        \(comment: self.swiftDescription)
        @\(macro)(bits: \(range.lowerBound)..<\(range.upperBound))
        \(context.accessLevel)var \(identifier: instanceName): \(typeName)

        """)
    }
  }
}
