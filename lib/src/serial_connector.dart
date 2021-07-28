import 'dart:async';
import 'dart:typed_data';

import 'package:modbus/modbus.dart';

class SerialConnector extends ModbusConnector {
  String _device;

  SerialConnector(this._device) {
    throw UnimplementedError("NOT IMPLEMENTED");
  }

  @override
  Future connect() {
    throw UnimplementedError("NOT IMPLEMENTED");
  }

  @override
  void write(int function, Uint8List data) {
    throw UnimplementedError("NOT IMPLEMENTED");
  }

  @override
  Future close() {
    throw UnimplementedError("NOT IMPLEMENTED");
  }

  @override
  void setUnitId(int unitId) {
    throw UnimplementedError("NOT IMPLEMENTED");
  }

  Uint8List _crc(Uint8List bytes) {
    var crc = BigInt.from(0xffff);
    var poly = BigInt.from(0xa001);

    for (var byte in bytes) {
      var bigByte = BigInt.from(byte);
      crc = crc ^ bigByte;
      for (int n = 0; n <= 7; n++) {
        int carry = crc.toInt() & 0x1;
        crc = crc >> 1;
        if (carry == 0x1) {
          crc = crc ^ poly;
        }
      }
    }
    //return crc.toUnsigned(16).toInt();
    var ret = Uint8List(2);
    ByteData.view(ret.buffer).setUint16(0, crc.toUnsigned(16).toInt());
    return ret;
  }
}
