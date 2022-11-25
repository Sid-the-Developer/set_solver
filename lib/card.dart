import 'package:flutter/material.dart';

class Card {
  int _num;
  Color _color;
  Shape _shape;
  Fill _fill;

  Card(
      {required number,
      required color,
      required shape,
      required fill})
      : _num = number,
        _color = color,
        _shape = shape,
        _fill = fill;
}

enum Fill { solid, open, striped }

enum Shape { pill, diamond, squiggle }
