class ModbusExceptionCodes {
  static const illegalFunction = 0x01; // Function Code not Supported
  static const illegalAddress = 0x02; // Output Address not exists
  static const illegalValue = 0x03; // Output Value not in Range
  static const serverFailure = 0x04; // Slave Deive Fails to process request
  static const acknowledge = 0x05; // Service Need Long Time to Execute
  static const serverBusy = 0x06; // Server Was Unable to Accept MB Request PDU
  static const gatewayPathNotAvailableProblem =
      0x0A; // Gateway Path not Available
  static const gatewayTargetFailedToResponse =
      0x0B; // Target Device Failed to Response
}

/// MODBUS Exception Super Class
/// Throw when a exception or errors happens in modbus protocol
class ModbusException implements Exception {
  final String msg;

  const ModbusException(this.msg);

  String toString() => 'MODBUS ERROR: $msg';
}

/// Connection Issue
/// Throw when a connection issues happens between modbus client and server
class ModbusConnectException extends ModbusException {
  ModbusConnectException(String msg) : super(msg);
}

/// Illegal Function
/// Throw when modbus server return error response function 0x01
class ModbusIllegalFunctionException extends ModbusException {
  ModbusIllegalFunctionException() : super('Illegal Function');
}

/// Illegal Address
/// Throw when modbus server return error response function 0x02
class ModbusIllegalAddressException extends ModbusException {
  ModbusIllegalAddressException() : super('Illegal Address');
}

/// Illegal Data Value
/// Throw when modbus server return error response function 0x03
class ModbusIllegalDataValueException extends ModbusException {
  ModbusIllegalDataValueException() : super('Illegal Data Value');
}

/// Server Failure
/// Throw when modbus server return error response function 0x04
class ModbusServerFailureException extends ModbusException {
  ModbusServerFailureException() : super('Server Failure');
}

/// Acknowledge
/// Throw when modbus server return error response function 0x05
class ModbusAcknowledgeException extends ModbusException {
  ModbusAcknowledgeException() : super('Acknowledge error');
}

/// Server Busy
/// Throw when modbus server return error response function 0x06
class ModbusServerBusyException extends ModbusException {
  ModbusServerBusyException() : super('Server Busy');
}

/// Gateway Problem
/// Throw when modbus server return error response function 0x0A and 0x0B
class ModbusGatewayProblemException extends ModbusException {
  ModbusGatewayProblemException() : super('Gateway Problem');
}

/// Buffer Exception
/// Throw when buffer is too small for the data to be stored.
class ModbusBufferException extends ModbusException {
  ModbusBufferException() : super('Buffer Exception');
}

/// Amount Exception
/// Throw when the address or amount input is mismatching.
class ModbusAmountException extends ModbusException {
  ModbusAmountException() : super('Amount Exception');
}
