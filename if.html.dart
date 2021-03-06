// Generated Dart class from HTML template.
// DO NOT EDIT.

// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('if_component');

#import('dart:html');
#import('component.dart');
#import('watcher.dart');
#import('webcomponents.dart');

/**
 * A web component implementing `<template instantiate="if ...">`.
 */
class IfComponent extends Component {
  IfCondition shouldShow;
  Element _childTemplate;
  Element _parent;
  Element _child;
  String _childId;
  WatcherDisposer _stopWatcher;

  IfComponent(root, elem)
    : super('if', root, elem);

  void created() {
    // TODO(sigmund): support document fragments, not just a single child.
    // TODO(sigmund): use logging and not assertions.
    assert(element.elements.length == 1);
    _childTemplate = element.elements[0];
    _childId = _childTemplate.id;
    if (_childId != null && _childId != '') {
      _childTemplate.id = '';
    }
    element.style.display = 'none';
    element.nodes.clear();
  }

  void inserted() {
    _stopWatcher = bind(() => shouldShow(scopedVariables), (e) {
      bool showNow = e.newValue;
      if (_child != null && !showNow) {
        _child.remove();
        _child = null;
      } else if (_child == null && showNow) {
        _child = _childTemplate.clone(true);
        if (_childId != null && _childId != '') {
          _child.id = _childId;
        }
        manager.expandDeclarations(_child).forEach((component) {
          component.scopedVariables = scopedVariables;
          component.created();
        });
        element.parent.nodes.add(_child);
      }
    });
  }

  void removed() {
    _stopWatcher();
    if (_child != null) {
      _child.remove();
    }
  }
}

/**
 * A condition whether the children of a '<template instantitate="if ...">' tag
 * should be displayed or not.
 */
typedef bool IfCondition(Map<String, Dynamic> variables);
