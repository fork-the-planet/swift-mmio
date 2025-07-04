# Type Mapping

A mapping between Swift types and their corresponding types in the CMSIS SVD XML schema.

| Swift Type                      | CMSIS SVD XML Schema Type  |
| ------------------------------- | -------------------------- |
| ``SVDAccess``                   | `accessType`               |
| ``SVDAddressBlock``             | `addressBlockType`         |
| ``SVDBitRangeLiteral``          | `bitRangeType`             |
| ``SVDBitRangeLsbMsb``           | `bitRangeLsbMsbStyle`      |
| ``SVDBitRangeOffsetWidth``      | `bitRangeOffsetWidthStyle` |
| ``SVDCluster``                  | `clusterType`              |
| ``SVDCPU``                      | `cpuType`                  |
| ``SVDCPUEndianness``            | `endianType`               |
| ``SVDCPUName``                  | `cpuNameType`              |
| ``SVDCPURevision``              | `revisionType`             |
| ``SVDDataType``                 | `dataTypeType`             |
| ``SVDDevice``                   | `device`                   |
| `Swift.String`                  | `dimableIdentifierType`    |
| ``SVDDimensionArrayIndex``      | `dimArrayIndexType`        |
| ``SVDDimensionElement``         | `dimElementGroup`          |
| `Swift.String`                  | `dimIndexType`             |
| ``SVDEnumeration``              | `enumerationType`          |
| ``SVDEnumerationCase``          | `enumeratedValueType`      |
| ``SVDEnumerationCaseDataValue`` | `enumeratedValueDataType`  |
| ``SVDEnumerationUsage``         | `enumUsageType`            |
| ``SVDField``                    | `fieldType`                |
| ``SVDFields``                   | `fieldsType`               |
| `Swift.String`                  | `identifierType`           |
| ``SVDInterrupt``                | `interruptType`            |
| ``SVDModifiedWriteValues``      | `modifiedWriteValuesType`  |
| ``SVDPeripheral``               | `peripheralType`           |
| ``SVDPeripherals``              | `peripherals`              |
| ``SVDProtection``               | `protectionStringType`     |
| ``SVDReadAction``               | `readActionType`           |
| ``SVDRegister``                 | `registerType`             |
| ``SVDRegisterProperties``       | `registerPropertiesGroup`  |
| ``SVDRegisters``                | `registersType`            |
| ``SVDSAUAccess``                | `sauAccessType`            |
| ``SVDSAURegion``                | `region`                   |
| ``SVDSAURegions``               | `sauRegionsConfig`         |
| `Swift.UInt64`                  | `scaledNonNegativeInteger` |
| `Swift.String`                  | `stringType`               |
| ``SVDWriteConstraint``          | `writeConstraintType`      |
| `Swift.Bool`                    | `xs:boolean`               |
| `Swift.String`                  | `xs:decimal`               |
| `Swift.UInt64`                  | `xs:integer`               |
| `Swift.String`                  | `xs:Name`                  |
| `Swift.String`                  | `xs:string`                |
