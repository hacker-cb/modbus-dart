import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../modbus.dart';
import 'acii_converter.dart';
import 'util.dart';

/// MODBUS TCP Connector
/// Simple protocol details: https://ipc2u.ru/articles/prostye-resheniya/modbus-tcp/
class TcpConnector extends ModbusConnector {
  final Logger log = new Logger('TcpConnector');

  var _address;
  int _port;
  ModbusMode _mode;
  int _tid = 0; //transaction ID
  late int _unitId;

  Socket? _socket;

  TcpConnector(this._address, this._port, this._mode);

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(_address, _port);
    _socket!.listen(_onData,
        onError: onError, onDone: onClose, cancelOnError: true);
  }

  @override
  Future<void> close() async {
    await _socket?.close();
    _socket?.destroy();
  }

  @override
  void setUnitId(int unitId) {
    _unitId = unitId;
  }

  void _onData(List<int> tcpData) {
    if (_mode == ModbusMode.ascii) tcpData = AsciiConverter.fromAscii(tcpData);

    log.finest('RECV: ' + dumpHexToString(tcpData));
    var view = ByteData.view(Uint8List.fromList(tcpData).buffer);
    int tid = view.getUint16(0); // ignore: unused_local_variable
    int len = view.getUint16(4);
    int unitId = view.getUint8(6); // ignore: unused_local_variable
    int function = view.getUint8(7);

    onResponse(function,
        tcpData.sublist(8, 8 + len - 2 /*unitId + function*/) as Uint8List);
  }

  @override
  void write(int function, Uint8List data) {
    _tid++;

    Uint8List tcpHeader = Uint8List(7); // Modbus Application Header
    ByteData.view(tcpHeader.buffer)
      ..setUint16(0, _tid, Endian.big)
      ..setUint16(4, 1 /*unitId*/ + 1 /*fn*/ + data.length, Endian.big)
      ..setUint8(6, _unitId);

    Uint8List fn = Uint8List(1); // Modbus Application Header
    ByteData.view(fn.buffer).setUint8(0, function);

    Uint8List tcpData = Uint8List.fromList(tcpHeader + fn + data);

    log.finest('SEND: ' + dumpHexToString(tcpData));

    if (_mode == ModbusMode.ascii) tcpData = AsciiConverter.toAscii(tcpData);

    _socket!.add(tcpData);
  }
}
