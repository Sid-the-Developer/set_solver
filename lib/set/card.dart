class Card {
  int _num;
  CardColor _color;
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

enum Fill { empty, partial, full }

enum Shape { diamond, oval, squiggle }

enum CardColor { red, green, purple }

enum Num { one, two, three }