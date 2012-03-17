# s2.2.7.4

codepageByLcid = require('../collation').codepageByLcid
iconvByLcid = require('../collation').iconvByLcid

TYPE = require('../data-type').TYPE
sprintf = require('sprintf').sprintf

parser = (buffer) ->
  columnCount = buffer.readUInt16LE()

  columns = []
  for c in [1..columnCount]
    userType = buffer.readUInt32LE()
    flags = buffer.readUInt16LE()
    typeNumber = buffer.readUInt8()
    type = TYPE[typeNumber]

    if !type
      throw new Error(sprintf('Unrecognised data type 0x%02X at offset 0x%04X', typeNumber, (buffer.position - 1)))

    #console.log(type)

    if (type.id & 0x30) == 0x20
      # xx10xxxx - s2.2.4.2.1.3
      # Variable length
      switch type.dataLengthLength
        when 1
          dataLength = buffer.readUInt8()
        when 2
          dataLength = buffer.readUInt16LE()
        when 4
          dataLength = buffer.readUInt32LE()
        else
          throw new Error("Unsupported dataLengthLength #{type.dataLengthLength} for data type #{type.name}")
    else
      dataLength = undefined

    if type.hasPrecision
      precision = buffer.readUInt8()
    else
      precision = undefined

    if type.hasScale
      scale = buffer.readUInt8()
    else
      scale = undefined

    if type.hasCollation
      # s2.2.5.1.2
      collationData = buffer.readBuffer(5)
      collation = {}

      collation.lcid = (collationData[2] & 0x0F) << 16
      collation.lcid |= collationData[1] << 8
      collation.lcid |= collationData[0]
      
      collation.codepage = codepageByLcid[collation.lcid]
      collation.iconv = iconvByLcid[collation.lcid]

      # This may not be extracting the correct nibbles in the correct order.
      collation.flags = collationData[3] >> 4
      collation.flags |= collationData[2] & 0xF0

      # This may not be extracting the correct nibble.
      collation.version = collationData[3] & 0x0F

      collation.sortId = collationData[4]
    else
      collation = undefined

    if type.hasTableName
      numberOfTableNameParts = buffer.readUInt8()
      tableName = for part in [1..numberOfTableNameParts]
        buffer.readUsVarchar('ucs2')
    else
      tableName = undefined

    colName = buffer.readBVarchar()

    column =
      userType: userType
      flags: flags
      type: type
      colName: colName
      collation: collation
      precision: precision
      scale: scale
      dataLength: dataLength
      tableName: tableName

    columns.push(column)
    columns[column.colName] = column

  # Return token
  name: 'COLMETADATA'
  event: 'columnMetadata'
  columns: columns

module.exports = parser
