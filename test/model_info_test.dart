import 'package:flutter_test/flutter_test.dart';
import 'package:urthate/urthate.dart' as urt;

void main() {
  test('generate sql', () {
    urt.ModelInfo foo = urt.ModelInfo(
      name: 'foo',
      columns: <urt.Column>[
        urt.Column(name: 'id', type: 'text', primary: true),
        urt.Column(name: 'created', type: 'datetime', notNull: true),
        urt.Column(name: 'active', type: 'bool'),
        urt.Column(name: 'bar', reference: urt.Reference('bar', urt.ReferenceType.oneToOne)),
      ],
      mapper: null,
    );

    urt.ModelInfo bar = urt.ModelInfo(
      name: 'bar',
      columns: <urt.Column>[
        urt.Column(name: 'id', type: 'text', primary: true),
        urt.Column(name: 'name', type: 'text', primary: true),
        urt.Column(name: 'email', type: 'text'),
      ],
      mapper: null,
    );

    urt.Urthate().register(foo);
    urt.Urthate().register(bar);

    print(foo.buildCreateTable());
    print(bar.buildCreateTable());
  });
}
