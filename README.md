# modbus-dart 

Simple Modbus client library for dart. Currently only the TCP connection is supported.

[![pub package](https://img.shields.io/pub/v/http.svg)](https://pub.dartlang.org/packages/modbus)


## Usage

### Single slave (Modbus RTU)

```dart
import 'package:modbus/modbus.dart' as modbus;


main(List<String> arguments) async {
    
  var client = modbus.createTcpClient(
    '10.170.1.20',
    port: 1001,
    mode: modbus.ModbusMode.rtu,
  );
    
  try {
    await client.connect();
    
    var slaveIdResponse = await client.reportSlaveId();
    
    print("Slave ID: " + slaveIdResponse);
  } finally {
    client.close();
  }
}
```

### Multi slaves with one connection (Modbus RTU)

```dart
import 'package:modbus/modbus.dart' as modbus;


main(List<String> arguments) async {
    
  var client = modbus.createTcpClient(
    '10.170.1.20',
    port: 1001,
    mode: modbus.ModbusMode.rtu,
  );
    
  try {
    await client.connect();
    
    client.setUnitId(100);
    var slaveIdResponse = await client.reportSlaveId();
    
    print("Slave ID: " + slaveIdResponse);

    client.setUnitId(150);
    var slaveIdResponse = await client.reportSlaveId();

    print("Slave ID: " + slaveIdResponse);
  } finally {
    client.close();
  }
}
```


## Limitations

SerialConnector is not implemented yet.
