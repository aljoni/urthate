import 'package:flutter_test/flutter_test.dart';
import 'package:urthate/src/sql_generator.dart';
import 'package:urthate/urthate.dart' as urt;

void main() {
  test('generate sql', () {
    urt.ModelInfo foo = urt.ModelInfo(
      name: 'foo',
      columns: {
        1: <urt.Column>[
          urt.Column(name: 'id', type: 'text', primary: true),
          urt.Column(name: 'created', type: 'datetime', notNull: true),
          urt.Column(name: 'active', type: 'bool'),
          urt.Column(name: 'bars', references: urt.Reference('bar', urt.ReferenceType.manyToMany)),
          urt.Column(name: 'bazs', references: urt.Reference('baz', urt.ReferenceType.oneToMany)),
        ],
      },
      mapper: null,
    );

    urt.ModelInfo bar = urt.ModelInfo(
      name: 'bar',
      columns: {
        1: <urt.Column>[
          urt.Column(name: 'id', type: 'text', primary: true),
          urt.Column(name: 'name', type: 'text', primary: true),
          urt.Column(name: 'email', type: 'text'),
          urt.Column(name: 'foos', references: urt.Reference('foo', urt.ReferenceType.manyToMany)),
          urt.Column(name: 'baz', references: urt.Reference('baz', urt.ReferenceType.oneToOne)),
        ],
      },
      mapper: null,
    );

    urt.ModelInfo baz = urt.ModelInfo(
      name: 'baz',
      columns: {
        1: <urt.Column>[
          urt.Column(name: 'id', type: 'text', primary: true),
          urt.Column(name: 'thing', type: 'text'),
        ],
      },
      mapper: null,
    );

    urt.Urthate ut = urt.Urthate(version: 1);

    ut.register(foo);
    ut.register(bar);
    ut.register(baz);

    SQLGenerator sqlGenerator = SQLGenerator();

    print(sqlGenerator.generateCreateTable(ut, foo));
    print(sqlGenerator.generateCreateTable(ut, bar));
    print(sqlGenerator.generateCreateTable(ut, baz));
    List<String> sqls = sqlGenerator.generateManyToManyTables(ut);
    for (String sql in sqls) {
      print(sql);
    }
  });
}
