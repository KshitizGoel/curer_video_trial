import 'package:flutter/material.dart';

class Call {
  Call(this.number);
  String number;
  bool held = false;
  bool muted = false;
}
