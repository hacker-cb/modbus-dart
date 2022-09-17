import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../modbus.dart';
import 'exceptions.dart';
import 'util.dart';

typedef void CompleterCallback(Completer completer, int function, Uint8List data);

/// MODBUS client
/// http://www.modbus.org/docs/Modbus_Application_Protocol_V1_1b.pdf
class ModbusClientImpl extends ModbusClient {
  final Logger log = new Logger('ModbusClientImpl');

  ModbusConnector _connector;

  Map<PendingKey, PendingCallback> _pendingMap = HashMap();
  Map<PendingKey, Completer> _waitingMap = HashMap();
  Queue<Request> _waitingQueue = DoubleLinkedQueue();

  ModbusClientImpl(this._connector, int unitId) {
    _connector.onResponse = _onConnectorData;
    _connector.onError = _onConnectorError;
    _connector.onClose = _onConnectorClose;
    _connector.setUnitId(unitId);
  }

  @override
  Future<void> connect() {
    return _connector.connect();
  }

  @override
  Future<void> close() {
    return _connector.close();
  }

  @override
  void setUnitId(int unitId) {
    return _connector.setUnitId(unitId);
  }

  void _onConnectorData(int function, Uint8List data) {
    log.finest("RECV: fn: " +
        function.toRadixString(16).padLeft(2, '0') +
        "h data: " +
        dumpHexToString(data));
    var key = PendingKey(function & 0x7f);

    var handler = _pendingMap.remove(key);
    handler?.respond(function, data);

    var waiter = _waitingMap.remove(key);
    log.finest('unlock $key');
    waiter?.complete();

    // if (_nextDataCallBack != null) _nextDataCallBack!(function, data);
  }

  void _onConnectorError(error, stackTrace) {
    _waitingMap.values.forEach((element) => element.completeError(error, stackTrace));
    _pendingMap.values.forEach((element) => element.completer.completeError(error, stackTrace));

    _pendingMap.clear();
    _waitingMap.clear();
    // _completer?.completeError(error, stackTrace);
    throw ModbusConnectException("Connector Error: ${error}");
  }

  void _onConnectorClose() {
    _waitingMap.values.forEach((element) => element.completeError(ModbusConnectException("Connector was closed before operation was completed")));
    _pendingMap.values.forEach((element) => element.completer.completeError(ModbusConnectException("Connector was closed before operation was completed")));

    _pendingMap.clear();
    _waitingMap.clear();

  }

  void _sendData(int function, Uint8List data) {
    log.finest("SEND: fn: " +
        function.toRadixString(16).padLeft(2, '0') +
        "h data: " +
        dumpHexToString(data));
    _connector.write(function, data);
  }

  Future<Uint8List> _executeFunctionImpl(
      int function, Uint8List data, CompleterCallback callback) {
    PendingKey key = PendingKey(function);
    Completer<Uint8List> completer = Completer();
    if (_waitingMap.containsKey(key)) {
      _waitingQueue.addLast(Request(function, data, callback, completer));
      log.finest('waiting queue length ${_waitingQueue.length} key $key');
    } else {
      Completer responseCompleter = Completer();
      _waitingMap[key] = responseCompleter;

      _sendData(function, Uint8List.fromList(data));
      _pendingMap[key] = PendingCallback(completer, callback);

      log.finest('lock $key');
      responseCompleter.future.whenComplete(() {
        if (_waitingQueue.isNotEmpty) {
          var request = _waitingQueue.removeFirst();
          _sendNext(request);
        }
      });
    }
    return completer.future;
  }

  void _sendNext(Request request) {
    PendingKey key = PendingKey(request.function);
    if (_waitingMap.containsKey(key)) {
      _waitingQueue.addFirst(request);
      log.finest('enqueue ${_waitingQueue.length} key $key');
      return;
    }
    Completer responseCompleter = Completer();
    _sendData(request.function, Uint8List.fromList(request.data));
    _pendingMap[key] = PendingCallback(request.completer, request.callback);
    _waitingMap[key] = responseCompleter;
    log.finest('lock $key');
    responseCompleter.future.whenComplete(() {
      if (_waitingQueue.isNotEmpty) {
        var next = _waitingQueue.removeFirst();
        _sendNext(next);
      }
    });
  }

  @override
  Future<Uint8List> executeFunction(int function, [Uint8List? data]) {
    if (data == null) data = Uint8List(0);
    return _executeFunctionImpl(function, data,
        (completer, responseFunction, responseData) {
      if (responseFunction == function + 0x80) {
        var errorCode = responseData.elementAt(0);
        ModbusException e;
        switch (errorCode) {
          case ModbusExceptionCodes.illegalFunction:
            e = ModbusIllegalFunctionException();
            break;
          case ModbusExceptionCodes.illegalAddress:
            e = ModbusIllegalAddressException();
            break;
          case ModbusExceptionCodes.illegalValue:
            e = ModbusIllegalDataValueException();
            break;
          case ModbusExceptionCodes.serverFailure:
            e = ModbusServerFailureException();
            break;
          case ModbusExceptionCodes.acknowledge:
            e = ModbusAcknowledgeException();
            break;
          case ModbusExceptionCodes.serverBusy:
            e = ModbusServerBusyException();
            break;
          case ModbusExceptionCodes.gatewayPathNotAvailableProblem:
          case ModbusExceptionCodes.gatewayTargetFailedToResponse:
            e = ModbusGatewayProblemException();
            break;
          default:
            e = ModbusException("Unknown error code: ${errorCode}");
            break;
        }
        completer!.completeError(e);
      } else {
        completer!.complete(responseData);
      }
    });
  }

  @override
  Future<Uint8List> reportSlaveId() async {
    var response = await executeFunction(ModbusFunctions.reportSlaveId);
    return response.sublist(1, response.elementAt(0) + 1);
  }

  @override
  Future<int> readExceptionStatus() async {
    var response = await executeFunction(ModbusFunctions.readExceptionStatus);
    var codes = ByteData.view(response.buffer).getUint8(0);
    return codes;
  }

  Future<List<bool?>> _readBits(int function, int address, int amount) async {
    var data = Uint8List(4);
    ByteData.view(data.buffer)
      ..setUint16(0, address)
      ..setUint16(2, amount);

    var response = await executeFunction(function, data);
    var responseView = ByteData.view(response.buffer);

    var ret = List<bool?>.filled(amount, null);
    for (int i = 0; i < amount; i++) {
      ret[i] = ((responseView.getUint8(1 /*byte count*/ + (i / 8).truncate()) >>
                  (i % 8)) &
              1) ==
          1;
    }
    return ret;
  }

  @override
  Future<List<bool?>> readCoils(int address, int amount) async {
    if (amount < 1 || amount > 2000) throw ModbusAmountException();

    return _readBits(ModbusFunctions.readCoils, address, amount);
  }

  @override
  Future<List<bool?>> readDiscreteInputs(int address, int amount) {
    if (amount < 1 || amount > 2000) throw ModbusAmountException();

    return _readBits(ModbusFunctions.readDiscreteInputs, address, amount);
  }

  Future<Uint16List> _readRegisters(
      int function, int address, int amount) async {
    var data = Uint8List(4);
    ByteData.view(data.buffer)
      ..setUint16(0, address)
      ..setUint16(2, amount);

    var response = await executeFunction(function, data);

    var responseView = ByteData.view(response.buffer);

    var ret = Uint16List(amount);
    for (int i = 0; i < amount; i++) {
      ret[i] = responseView.getUint16(1 /*byte count(amount *2)*/ + 2 * i);
    }
    return ret;
  }

  @override
  Future<Uint16List> readHoldingRegisters(int address, int amount) async {
    if (amount < 1 || amount > 125) throw ModbusAmountException();

    return _readRegisters(
        ModbusFunctions.readHoldingRegisters, address, amount);
  }

  @override
  Future<Uint16List> readInputRegisters(int address, int amount) async {
    if (amount < 1 || amount > 0x007D) throw ModbusAmountException();

    return _readRegisters(ModbusFunctions.readInputRegisters, address, amount);
  }

  @override
  Future<bool> writeSingleCoil(int address, bool to_write) async {
    var data = Uint8List(4);
    ByteData.view(data.buffer)
      ..setUint16(0, address)
      ..setUint16(2, to_write ? 0xff00 : 0x0000);

    var response = await executeFunction(ModbusFunctions.writeSingleCoil, data);
    var responseView = ByteData.view(response.buffer);

    return responseView.getUint16(2) == 0xff00 ? true : false;
  }

  @override
  Future<int> writeSingleRegister(int address, int value) async {
    var data = Uint8List(4);
    ByteData.view(data.buffer)
      ..setUint16(0, address)
      ..setUint16(2, value);

    var response =
        await executeFunction(ModbusFunctions.writeSingleRegister, data);
    var responseView = ByteData.view(response.buffer);

    return responseView.getUint16(2);
  }

  @override
  Future<void> writeMultipleCoils(int address, List<bool> values) async {
    int amount = values.length;

    if (amount < 1 || amount > 0x007b) throw ModbusAmountException();

    int numberOfBytes = (amount / 8).ceil();

    var data = Uint8List(4 + 1 + numberOfBytes);
    var dataView = ByteData.view(data.buffer)
      ..setUint16(0, address)
      ..setUint16(2, amount)
      ..setUint8(4, numberOfBytes);

    // Make list with full bytes
    if (amount % 8 != 0)
      values.addAll(Iterable.generate(8 - (amount % 8), (i) => false));

    for (int i = 0; i < numberOfBytes; i++) {
      var v = 0;
      for (int j = 0; j < 8; j++) {
        v |= (values.elementAt(i * 8 + j) ? 1 : 0) << j;
      }
      dataView.setUint8(5 + i, v);
    }

    await executeFunction(ModbusFunctions.writeMultipleCoils, data);
  }

  @override
  Future<void> writeMultipleRegisters(int address, Uint16List values) async {
    int amount = values.length;

    if (amount < 1 || amount > 123) throw ModbusAmountException();

    int numberOfBytes = amount * 2;

    var data = Uint8List(4 + 1 + numberOfBytes);
    var dataView = ByteData.view(data.buffer)
      ..setUint16(0, address)
      ..setUint16(2, amount)
      ..setUint8(4, numberOfBytes);

    for (int i = 0; i < amount; i++) {
      dataView.setUint16(5 + i * 2, values.elementAt(i));
    }

    await executeFunction(ModbusFunctions.writeMultipleRegisters, data);
  }
}
class PendingKey {
  int function;
  PendingKey(this.function);

  @override
  int get hashCode {
    return 31 + function;
  }

  @override
  bool operator ==(Object other) {
    if (other is PendingKey) {
      return function == other.function;
    }
    return false;
  }

  @override
  String toString() {
    return 'PendingKey($hashCode)';
  }

}
class PendingCallback {
  Completer<Uint8List> completer;
  CompleterCallback callback;
  PendingCallback(this.completer, this.callback);

  void respond(int function, Uint8List data) {
    callback(completer, function, data);
  }
}
class Request {
  int function;
  Uint8List data;
  CompleterCallback callback;
  Completer<Uint8List> completer;
  Request(this.function, this.data, this.callback, this.completer);
}