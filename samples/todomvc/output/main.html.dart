// Generated Dart class from HTML template.
// DO NOT EDIT.

#library('main_html');

#import('dart:html');

// Code from components
#import('footer.html.dart');
#import('newform.html.dart');
#import('item.html.dart');
#import('toggleall.html.dart');
// TODO(jmesserly): ideally these would be package: imports
#import('../../../if.html.dart');
#import('../../../list.html.dart');

// TODO(Terry): All script tags referenced in the .html file are prefixed
//              likewise all expressions in the HTML are prefixed as well.
#import('../../../watcher.dart');
#import('../../../webcomponents.dart');

#import('model.dart');
#import('todo.dart');

/** Create the views and bind them to models (will be auto-generated). */
mainMain() {
  _componentsSetUp();

  // create view.
  var body = new DocumentFragment.html(INITIAL_PAGE);
  manager.expandDeclarations(body);

  // attach model where needed.
  var xlist = manager[body.query("[is=x-list]")];
  xlist.items = () => app.todos;

  // attach view to the document.
  document.body.nodes.add(body);
}

/** Set up components used by this application (will be auto-generated). */
void _componentsSetUp() {
  // use mirrors when they become available.
  Map<String, Function> map = {
    'x-todo-footer': (root, elem) => new FooterComponent(root, elem),
    'x-todo-form': (root, elem) => new FormComponent(root, elem),
    'x-toggle-all': (root, elem) => new ToggleComponent(root, elem),
    'x-list': (root, elem) => new ListComponent(root, elem),
    'x-if': (root, elem) {
      // TODO(terry): Better mechanism to disambiguate each if and multiple
      //              x-list as well.
      var res = new IfComponent(root, elem);
      var condition = elem.attributes['instantiate'].substring('if '.length);
      if (condition == 'viewModel.hasElements') {
        res.shouldShow = (_) => viewModel.hasElements;
      } else if (condition == 'viewModel.isVisible(x)') {
        res.shouldShow = (vars) => viewModel.isVisible(vars['x']);
      }
      return res;
    },
    'x-todo-row': (root, elem) => new TodoItemComponent(root, elem),
  };
  initializeComponents((String name) => map[name]);
}

/** DOM describing the initial view of the app (will be auto-generated). */
final INITIAL_PAGE = """
  <section id="todoapp">
    <header id="header">
      <h1 class='title'>todos</h1>
      <div is="x-todo-form"></div>
    </header>
    <section id="main">
      <div is="x-toggle-all"></div>
      <ul id="todo-list">
        <template iterate="x in app.todos" is="x-list">
          <template instantiate="if viewModel.isVisible(x)" is="x-if">
            <li is="x-todo-row" data-todo="x"></li>
          </template>
        </template>
      </ul>
    </section>
    <template instantiate="if viewModel.hasElements" is="x-if">
      <footer is="x-todo-footer" id="footer"></footer>
    </template>
  </section>
  <footer id="info">
    <p>Double-click to edit a todo.</p>
    <p>Credits: the <a href="http://www.dartlang.org">Dart</a> team </p>
    <p>Part of <a href="http://todomvc.com">TodoMVC</a></p>
  </footer>
""";
