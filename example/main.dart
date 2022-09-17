import 'package:modbus/modbus.dart' as modbus;
import 'package:logging/logging.dart';

main(List<String> arguments) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time} [${rec.loggerName}]: ${rec.message}');
  });

  var client = modbus.createTcpClient('10.170.1.20',
      port: 1001, mode: modbus.ModbusMode.rtu, timeout: Duration(seconds: 5));

  try {
    await client.connect();

    var slaveIdResponse = await client.reportSlaveId();

    StringBuffer sb = StringBuffer();
    slaveIdResponse.forEach((f) {
      sb.write(f.toRadixString(16).padLeft(2, '0'));
      sb.write(" ");
    });
    print("Slave ID: " + sb.toString());

    var exceptions = await client.readExceptionStatus();

    print("Exceptions: " + exceptions.toRadixString(2));

    {
      var registers = await client.readInputRegisters(0x0002, 6);
      for (int i = 0; i < registers.length; i++) {
        print("REG_I[${i}]: " + registers.elementAt(i).toString());
      }
    }
  } finally {
    client.close();
  }
}
