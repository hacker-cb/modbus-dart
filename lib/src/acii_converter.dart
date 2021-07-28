import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../modbus.dart';

class AsciiConverter {
  static final Logger log = new Logger('AsciiConverter');

  static Uint8List fromAscii(List<int> tcpData) {
    String str = String.fromCharCodes(tcpData);
    log.finest('From ASCII: ' + str);
    if (str.length % 2 != 0)
      throw ModbusException("ASCII string is not even count");
    if (!str.endsWith(String.fromCharCodes([0x0d, 0xa])))
      throw ModbusException("Invalid ASCII received");
    List<int> ret = [];
    for (int i = 0; i < str.length - 2 /*without CRLF*/; i += 2) {
      ret.add(int.parse(str.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(ret);
  }

  static Uint8List toAscii(List<int> tcpData) {
    StringBuffer sb = StringBuffer();
    tcpData.forEach((d) {
      sb.write(d.toRadixString(16).padLeft(2, '0'));
    });
    sb.write(String.fromCharCodes([0x0d, 0xa]));
    String str = sb.toString();
    log.finest('to ASCII: ' + str);
    return Uint8List.fromList(str.codeUnits);
  }
}
