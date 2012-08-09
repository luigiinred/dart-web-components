// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Polyfill script for custom elements. To use this script, your app must
 * create a CustomElementsManager with the appropriate lookup function before
 * doing any DOM queries or modifications.
 * Currently, all custom elements must be registered with the polyfill.  To
 * register custom elements, provide the appropriate lookup function to your
 * CustomElementsManager.
 *
 * This script does an XMLHTTP request, so to test using custom elements with
 * file:// URLs you must run Chrome with `--allow-file-access-from-files`.
 *
 * Other helpful Chrome flags are:
 * `--enable-shadow-dom --enable-scoped-style --enable-devtools-experiments`
 */
#library('webcomponents');

#import('dart:html');
#import('dart:mirrors');

// TODO(jmesserly): this is here so we can set up the lexical scopes.
// A component needs a way of knowing the <element> tag that was in scope for
// template expansions.
#import('component.dart');

#source('lib/list_map.dart');

// typedefs
typedef WebComponent WebComponentFactory(Element elt);

// Globals
final int REQUEST_DONE = 4;
CustomElementsManager _manager;
CustomElementsManager get manager() {
  if (_manager == null)
    _manager = new CustomElementsManager._();
  return _manager;
}

// TODO(jmesserly): we should probably return something here that supports
// dispose, to unregister the mutation observer.
/**
 * Initialize web components, optionally with the controller to use for data
 * binding.
 */
void initializeComponents([controller]) {
  manager._loadComponents(controller);
}

void registerComponent(CustomDeclaration declaration) {
  manager._customDeclarations[declaration.name] = declaration;
}

/** A Dart wrapper for a web component. */
abstract class WebComponent {
  /** The web component element wrapped by this class. */
  abstract Element get element();

  /** Invoked when this component gets created. */
  void created(ShadowRoot shadowRoot) {}

  /** Invoked when this component gets inserted in the DOM tree. */
  void inserted() {}

  /** Invoked when any attribute of the component is modified. */
  void attributeChanged(
      String name, String oldValue, String newValue) {}

  /** Invoked when this component is removed from the DOM tree. */
  void removed() {}
}

/** Loads and manages the custom elements on a page. */
class CustomElementsManager {
  final bool _USE_EXPANDO = true;
  /**
   * Maps tag names to our internal dart representation of the custom element.
   */
  Map<String, CustomDeclaration> _customDeclarations;

  // TODO(samhop): evaluate possibility of using vsm's trick of storing
  // arbitrary Dart objects directly on DOM objects rather than this map.
  /** Maps DOM elements to the user-defiend corresponding dart objects. */
  ListMap<Element, WebComponent> _customElements;

  WebComponent _unwrap(Element e) {
    return _USE_EXPANDO ? e.dynamic.xtag : _customElements[e];
  }

  void _setWrapper(Element e, WebComponent component) {
    if (_USE_EXPANDO) {
      e.dynamic.xtag = component;
    } else {
      _customElements[e] = component;
    }
  }

  MutationObserver _insertionObserver;

  CustomElementsManager._() {
    // TODO(samhop): check for ShadowDOM support
    _customDeclarations = <CustomDeclaration>{};
    // We use a ListMap because DOM objects aren't hashable right now.
    // TODO(samhop): DOM objects (and everything else) should be hashable
    if (!_USE_EXPANDO) {
      _customElements = new ListMap<Element, WebComponent>();
    }
    initializeInsertedRemovedCallbacks(document);
  }

  /**
   * Locate all external component files, load each of them, and expand
   * declarations.
   */
  void _loadComponents(declaringScope) {
    expandDeclarations(null, declaringScope);
    manager._expandDeclarations(null, insert: true);
  }

  /**
   * Look for all custom elements under [root] and expand them appropriately.
   * This calls the [created] event on a webcomponent, but it will not insert
   * the component in the DOM tree (and hence it won't call [inserted].
   */
  List expandDeclarations(Element root, declaringScope) {
    var components = _expandDeclarations(root, insert: false);
    for (var comp in components) {
      // TODO(jmesserly): it's unfortunate we need to handle databinding here.
      // I think this is a consequence of using custom elements as our
      // controller.
      if (comp is Component) {
        comp.declaringScope = declaringScope;
      }
    }
    return components;
  }

  /** Look for all custom elements uses and expand them appropriately. */
  List _expandDeclarations([Element root, bool insert = true]) {
    var newCustomElements = [];
    var target;
    var rootUnderTemplate = false;
    if (root == null) {
      target = document.body;
    } else {
      target = root;
      rootUnderTemplate = root.matchesSelector('template *');
    }
    for (var declaration in _customDeclarations.getValues()) {
      var selector = '${declaration.extendz}[is=${declaration.name}], ${declaration.name}';
      var all = target.queryAll(selector);
      // templates are innert and should not be expanded.
      var activeElements = all.filter(
          (e) => !e.matchesSelector('template *'));
      if (root != null && root.matchesSelector(selector)
         && !rootUnderTemplate) {
        activeElements.add(root);
      }
      for (var e in activeElements) {
        var component = _unwrap(e);
        if (component == null) {
          component = declaration.morph(e);
          newCustomElements.add(component);
        }
        if (insert) {
          component.inserted();
        }
      }
    }
    return newCustomElements;
  }


  /** Fire the [removed] event on all web components under [root]. */
  void _removeComponents(Element root) {
    for (var decl in _customDeclarations.getValues()) {
      for (var e in root.queryAll('${decl.extendz}[is=${decl.name}]')) {
        if (_unwrap(e) != null) _unwrap(e).removed();
      }
      if (root.matchesSelector('${decl.extendz}[is=${decl.name}]')) {
        if (_unwrap(root) != null) _unwrap(root).removed();
      }
    }
  }

  /**
   * Expands the given html string into a custom element.
   * Assumes only one element use in htmlString (or only returns the
   * first one) and assumes corresponding custom element is already
   * registered.
   */
  WebComponent expandHtml(String htmlString) {
    return expandElement(new Element.html(htmlString));
  }

  /** Expand [element], assuming it is a webcomponent. */
  WebComponent expandElement(Element element) {
    var declaration = _customDeclarations[element.attributes['is']];
    // TODO(jmesserly): this should throw an Exception
    if (declaration == null) throw 'No such custom element declaration';
    return declaration.morph(element);
  }

  WebComponent operator [](Element element) => _unwrap(element);

  // Initializes management of inserted and removed
  // callbacks for WebComponents below root in the DOM. We need one of these
  // for every shadow subtree, since mutation observers can't see across
  // shadow boundaries.
  void initializeInsertedRemovedCallbacks(Element root) {
    _insertionObserver = new MutationObserver((mutations, observer) {
      for (var mutation in mutations) {
        // TODO(samhop): remove this test if it turns out that it always passes
        if (mutation.type == 'childList') {
          for (var node in mutation.addedNodes) {
            if (node is Element) _expandDeclarations(node);
          }
          for (var node in mutation.removedNodes) {
            if (node is Element) _removeComponents(node);
          }
        }
      }
    });
    _insertionObserver.observe(root, childList: true, subtree: true);
  }
}

bool _hasShadowRoot;

/**
 * True if the browser supports the [ShadowRoot] element and it is enabled.
 * See the [Shadow DOM spec](http://www.w3.org/TR/shadow-dom/) for more
 * information about the ShadowRoot.
 */
bool get hasShadowRoot() {
  if (_hasShadowRoot == null) {
    try {
      // TODO(jmesserly): it'd be nice if we could check this without causing
      // an exception to be thrown.
      new ShadowRoot(new DivElement());
      _hasShadowRoot = true;
    } catch (var e) {
      _hasShadowRoot = false;
      // Hide <template> elements.
      // TODO(jmesserly): This is a workaround because we don't distribute
      // children correctly. It's not actually the right fix.
      var style = new Element.html(
          @'<style type="text/css">template { display: none; }</style>');
      document.head.nodes.add(style);
    }
  }
  return _hasShadowRoot;
}

WebComponentFactory _findWebComponentCtor(String ctorName) {
  var names = ctorName.split('.');
  // TODO(jmesserly): can we support library prefixes? Doesn't seem feasible
  // unless we track the declaring library.
  if (names.length > 2) {
    throw new UnsupportedOperationException(
        'constructor name has too many dots: $ctorName');
  }
  var typeName = names[0];
  ctorName = (names.length > 1) ? names[1] : '';

  var mirror = currentMirrorSystem();
  for (var lib in mirror.libraries.getValues()) {
    var cls = lib.classes[typeName];
    if (cls != null) {
      return (Element elt) {
        var future = cls.newInstance(ctorName, [reflect(elt)]);
        // type check, use "as" when available.
        WebComponent comp = future.value.reflectee;
        return comp;
      };
    }
  }
}

// TODO(jacobr): need to support components that extend other components.
class CustomDeclaration {
  String name;
  String extendz;
  String constructor;
  Element template;
  final bool applyAuthorStyles;

  WebComponentFactory _createInstance;

  CustomDeclaration(this.name, this.extendz, this.template,
                     this.applyAuthorStyles, this.constructor) {

    // Find and cache the constructor function:
    _createInstance = _findWebComponentCtor(constructor);
  }

  int hashCode() => name.hashCode();

  operator ==(other) {
    if (other is! CustomDeclaration) {
      return false;
    } else {
      return other.name == name &&
             other.extendz == extendz &&
             other.constructor == constructor &&
             other.template == template;
    }
  }

  // TODO(samhop): better docs
  /**
   * Modify the DOM for e, return a new Dart object corresponding to it.
   * Returns null if this custom declaration has no template element.
   */
  WebComponent morph(Element e) {
    if (template == null) {
      return null;
    }

    var shadowRoot;
    if (hasShadowRoot) {
      shadowRoot = new ShadowRoot(e);
      shadowRoot.resetStyleInheritance = false;
      if (applyAuthorStyles) {
        shadowRoot.applyAuthorStyles = true;
      }
    } else {
      print("XXX warning... very incomplete shadow root polyfill!");
      // Remove the old ShadowRoot, if any
      // TODO(jmesserly): can we avoid morphing the same node twice?
      // In any case, removal is not the right behavior. For inherited
      // components you can have more than one ShadowRoot.
      shadowRoot = e.query('.shadowroot');
      if (shadowRoot != null && shadowRoot.parent == e) shadowRoot.remove();

      // TODO(jmesserly): distribute children to insertion points.
      shadowRoot = new Element.html('<div class="shadowroot"></div>');
      e.nodes.add(shadowRoot);
    }

    template.nodes.forEach((node) => shadowRoot.nodes.add(node.clone(true)));

    var newCustomElement = _createInstance(e);
    manager._setWrapper(e, newCustomElement);
    manager.expandDeclarations(shadowRoot, newCustomElement);
    newCustomElement.created(shadowRoot);
    manager._expandDeclarations(shadowRoot, insert: true);

    // TODO(samhop): investigate refactoring/redesigning the API so that
    // components which don't need their attributes observed don't have an
    // observer created, for perf reasons.
    var attributeObserver = new MutationObserver((mutations, observer) {
      for (var mutation in mutations) {
        if (mutation.type == 'attributes') {
          var attrName = mutation.attributeName;
          Element element = mutation.target;
          newCustomElement.attributeChanged(attrName,
              mutation.oldValue, element.attributes[attrName]);
        }
      }
    });
    attributeObserver.observe(e, attributes: true, attributeOldValue: true);

    // Listen for all insertions and deletions on the DOM so that we can
    // catch custom elements being inserted and call the appropriate callbacks.
    manager.initializeInsertedRemovedCallbacks(shadowRoot);
    return newCustomElement;
  }
}
