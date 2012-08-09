// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('list_component');

#import('dart:mirrors');
#import('dart:html');
#import('component.dart');
#import('watcher.dart');
#import('webcomponents.dart');

/**
 * A web component implementing `<template iterate=...>`.
 */
class ListComponent extends Component {
  String _loopVar;
  String _loopItems;
  Element _childTemplate;
  Element _parent;
  WatcherDisposer _stopWatcher;

  ListComponent(elem)
      : super('list', elem) {
    var match = const RegExp(@"{{(.*) in (.*)}}").firstMatch(
          elem.attributes['iterate']);
    _loopVar = match.group(1);
    _loopItems = match.group(2);
  }

  List items() => mirrorGet(declaringScope, _loopItems).reflectee;

  void created(ShadowRoot root) {
    super.created(root);
    // TODO(sigmund): support document fragments, not just a single child.
    // TODO(sigmund): use logging and not assertions.
    assert(element.elements.length == 1);
    _childTemplate = element.elements[0];
    element.nodes.clear();
    _parent = element.parent;
  }

  void inserted() {
    root.nodes.clear();
    _stopWatcher = bind(items, (_) {
      for (var n in _parent.elements) {
        var wrapper = manager[n];
        if (wrapper != this) {
          if (wrapper != null) wrapper.removed();
          n.remove();
        }
      }
      for (var item in items()) {
        var child = _childTemplate.clone(true);
        // TODO(jmesserly): should support children that aren't WebComponents
        manager.expandDeclarations(child,
            new ComponentScope(declaringScope, new Map()..[_loopVar] = item));

        _parent.nodes.add(child);
      }
    });
  }

  void removed() {
    _stopWatcher();
    for (var n in _parent.elements) {
      var wrapper = manager[n];
      if (wrapper != null && wrapper != this) {
        wrapper.removed();
      }
    }
  }
}
