import 'package:flutter_test/flutter_test.dart';
import 'package:urthate/urthate.dart' as ut;

void main() {
  test('generate sql', () {
    ut.ModelInfo foo = ut.ModelInfo(
      name: 'foo',
      columns: <ut.Column>[
        ut.Column(name: 'id', type: 'text', primary: true),
        ut.Column(name: 'created', type: 'datetime', notNull: true),
        ut.Column(name: 'active', type: 'bool'),
        ut.Column(name: 'bar', reference: ut.Reference('bar', ut.ReferenceType.oneToOne)),
      ],
      mapper: null,
    );

    ut.ModelInfo bar = ut.ModelInfo(
      name: 'bar',
      columns: <ut.Column>[
        ut.Column(name: 'id', type: 'text', primary: true),
        ut.Column(name: 'name', type: 'text', primary: true),
        ut.Column(name: 'email', type: 'text'),
      ],
      mapper: null,
    );

    ut.Urthate().register(foo);
    ut.Urthate().register(bar);

    print(foo.buildCreateTable());
  });
}
