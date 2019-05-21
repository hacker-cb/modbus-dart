# modbus-dart 

MODBUS client library

[![pub package](https://img.shields.io/pub/v/http.svg)](https://pub.dartlang.org/packages/modbus)


## Using

import 'package:modbus/modbus.dart' as modbus;

```dart
  import 'package:modbus/modbus.dart' as modbus;


  main(List<String> arguments) async {
    
    var client = modbus.createTcpClient('10.170.1.20', port: 1001, mode: modbus.ModbusMode.rtu);

    try {
      await client.connect();

      var slaveIdResponse = await client.reportSlaveId();

      print("Slave ID: " + slaveIdResponse);
    } finally {
      client.close();
    }
    
  }
```


## Limitations

SerialConnector is not implemented yet