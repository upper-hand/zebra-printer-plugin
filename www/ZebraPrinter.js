var exec = require('cordova/exec');

exports.wifi = {
  discover: function (responsesTimeout, success, error) {
    exec(success, error, 'ZebraPrinter', 'wifiDiscover', [responsesTimeout]);
  },
  isConnected: function (success, error) {
      exec(success, error, 'ZebraPrinter', 'wifiIsConnected', []);
  },
  connect: function (address, port, success, error) {
      exec(success, error, 'ZebraPrinter', 'wifiConnect', [address, port]);
  },
  disconnect: function (success, error) {
      exec(success, error, 'ZebraPrinter', 'wifiDisconnect', []);
  },
  send: function (zpl, success, error) {
      exec(success, error, 'ZebraPrinter', 'wifiSend', [zpl]);
  },
  print: function (zpl, success, error) {
      exec(success, error, 'ZebraPrinter', 'wifiPrint', [zpl]);
  },
  read: function (success, error) {
    exec(success, error, 'ZebraPrinter', 'wifiRead', []);
  },
};

exports.bluetooth = {
  discover: function (scanTime, success, error) {
    exec(success, error, 'ZebraPrinter', 'bluetoothDiscover', [scanTime]);
  },
  isConnected: function (success, error) {
      exec(success, error, 'ZebraPrinter', 'bluetoothIsConnected', []);
  },
  connect: function (device, success, error) {
      exec(success, error, 'ZebraPrinter', 'bluetoothConnect', [device]);
  },
  disconnect: function (success, error) {
      exec(success, error, 'ZebraPrinter', 'bluetoothDisconnect', []);
  },
  send: function (zpl, success, error) {
      exec(success, error, 'ZebraPrinter', 'bluetoothSend', [zpl]);
  },
};
