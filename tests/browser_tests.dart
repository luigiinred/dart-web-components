// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jmesserly): need a lot more tests here
// TODO(jmesserly): using the _tests suffix to prevent run.sh from running this
// Ideally this would be called component_test.
/** Basic sanity test for [IfComponent] and [ListComponent]. */
#library('browser_tests');

#import('dart:html');
#import('package:unittest/unittest.dart');
#import('package:unittest/html_config.dart');
#import('../if_component.dart');
#import('../list_component.dart');
#import('../webcomponents.dart');
#import('../watcher.dart');

class Item {
  bool visible = true;
}

class AppModel {
  final List<Item> items;
  bool showFooter = false;

  AppModel() : items = [];
}

AppModel app;

main() {
  useHtmlConfiguration();

  app = new AppModel();
  _appSetUp();

  test('if was created', () {
    var ifEl = query('#cool-if');
    expect(ifEl, isNotNull);
    var ifComp = manager[ifEl];
    expect(ifComp, isNotNull);
    app.showFooter = true;
    expect(ifComp.shouldShow(null));
    app.showFooter = false;
    expect(!ifComp.shouldShow(null));
  });

  test('if responds to state change', () {
    var ifEl = query('#cool-if');
    var ifComp = manager[ifEl];
    app.showFooter = true;
    expect(query('#cool-footer'), isNull);
    dispatch();
    var footer = query('#cool-footer');
    expect(footer, isNotNull);
    expect(footer.parent, equals(ifEl.parent));

    var children = footer.parent.nodes;
    expect(children.indexOf(footer), greaterThan(children.indexOf(ifEl)));

    app.showFooter = false;
    expect(query('#cool-footer'), isNotNull);
    dispatch();
    expect(query('#cool-footer'), isNull);
  });


  test('list was created', () {
    var listEl = query('#cool-list');
    expect(listEl, isNotNull);
    var list = manager[listEl];
    expect(list, isNotNull);
    expect(list.items(), equals(app.items));
  });

  test('list responds to state change', () {
    app.items.add(new Item());
    app.items.add(new Item());
    app.items.add(new Item());

    var ul = query('#cool-list-host');
    expect(queryAll('.cool-item').length, 0);
    dispatch();
    // TODO(jmesserly): investigate why this only updates async
    window.setTimeout(expectAsync0(() {
      expect(queryAll('.cool-item').length, 3);
      var items = queryAll('.cool-item');
      expect(items[0].parent, equals(ul));

      app.items[1].visible = false;
      dispatch();
      expect(queryAll('.cool-item').length, 2);

      app.items.clear();
      dispatch();
      expect(queryAll('.cool-item').length, 0);
    }), 0);
  });
}

/** Create the views and bind them to models (will be auto-generated). */
void _appSetUp() {
  _componentsSetUp();

  // create view.
  var body = new DocumentFragment.html(INITIAL_PAGE);
  manager.expandDeclarations(body);

  // attach model where needed.
  manager[body.query("[is=x-list]")].items = () => app.items;

  // attach view to the document.
  document.body.nodes.add(body);
}

/** Set up components used by this application (will be auto-generated). */
void _componentsSetUp() {
  // Use mirrors when they become available.
  var map = {
    'x-list': (elem) => new ListComponent(elem),
    'x-if': (elem) {
      var res = new IfComponent(elem);
      var condition = elem.attributes['instantiate'].substring('if '.length);
      if (condition == 'app.showFooter') {
        res.shouldShow = (_) => app.showFooter;
      } else if (condition == 'item.visible') {
        res.shouldShow = (vars) => vars['item'].visible;
      }
      return res;
    },
  };

  initializeComponents((name) => map[name]);
}

/** DOM describing the initial view of the app (will be auto-generated). */
final INITIAL_PAGE = """
  <ul id="cool-list-host">
    <template iterate="{{item in app.items}}" is="x-list" id="cool-list">
      <template instantiate="if item.visible" is="x-if">
        <li class="cool-item">some cool data</li>
      </template>
    </template>
  </ul>
  <template instantiate="if app.showFooter" is="x-if" id="cool-if">
    <footer id="cool-footer"></footer>
  </template>
""";
