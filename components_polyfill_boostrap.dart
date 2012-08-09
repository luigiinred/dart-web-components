// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Bootstrap polyfill script for custom elements.
 * This script enables defining custom elements with blocks of dart code
 * embedded within an html page juast as you would define web components using
 * JavaScript.
 * This script only works with properly with dartium however to use it you must
 * compiled it to JavasScript due to a bug with injecting additional dart
 * scripts into a page after dart code has already run (b/4636).
 *
 * The script does an XMLHTTP request, so
 * to test using locally defined custom elements you must run chrome with the
 * flag -allow-file-access-from-files.
 */

#library('webcomponents_bootstrap');

#import('dart:html');
#import('dart:uri');

final POLYFILL_LIBRARY_PACKAGE = "package:webcomponents/webcomponents.dart";

final int REQUEST_DONE = 4;

// TODO(jacobr): with mirror support this list doesn't need to be hard coded.
// You can instead create a test element given a tag name and then determine
// its class.
final _tagToClassName = const {
    'a': 'AnchorElement',
    'area': 'AreaElement',
    'button': 'ButtonElement',
    'br': 'BRElement',
    'base': 'BaseElement',
    'body': 'BodyElement',
    'canvas': 'CanvasElement',
    'dl': 'DListElement',
    'details': 'DetailsElement',
    'div': 'DivElement',
    'embed': 'EmbedElement',
    'fieldset': 'FieldSetElement',
    'form': 'Form',
    'hr': 'HRElement',
    'head': 'HeadElement',
    'h1': 'HeadingElement',
    'h2': 'HeadingElement',
    'h3': 'HeadingElement',
    'h4': 'HeadingElement',
    'h5': 'HeadingElement',
    'h6': 'HeadingElement',
    'html': 'HtmlElement',
    'iframe': 'IFrameElement',
    'ImageElement':' img',
    'input': 'InputElement',
    'keygen': 'KeygenElement',
    'li': 'LIElement',
    'label': 'LabelElement',
    'legend': 'LegendElement',
    'link': 'LinkElement',
    'map': 'MapElement',
    'menu': 'MenuElement',
    'meter': 'MeterElement',
    'ol': 'OListElement',
    'object': 'ObjectElement',
    'optgroup': 'OptGroupElement',
    'output': 'OutputElement',
    'p': 'ParagraphElement',
    'param': 'ParamElement',
    'pre': 'PreElement',
    'progress': 'ProgressElement',
    'script': 'ScriptElement',
    'select': 'SelectElement',
    'source': 'SourceElement',
    'span': 'SpanElement',
    'style': 'StyleElement',
    'caption': 'TableCaptionElement',
    'td': 'TableCellElement',
    'col': 'TableColElement',
    'table': 'TableElement',
    'tr': 'TableRowElement',
    // 'TableSectionElement'  <thead> <tbody> <tfoot>
    'textarea': 'TextAreaElement',
    'title': 'TitleElement',
    'track': 'TrackElement',
    'ul': 'UListElement',
    'video': 'VideoElement'};

var PROXY_ELEMENT_MEMBERS = """
  // This is a temporary hack until Dart supports subclassing elements.
  // TODO(jacobr): use mirrors instead.

  NodeList get nodes() => _r.nodes;

  void set nodes(Collection<Node> value) { _r.nodes = value; }

  /**
   * Replaces this node with another node.
   */
  Node replaceWith(Node otherNode) { _r.replaceWith(otherNode); }

  /**
   * Removes this node from the DOM.
   */
  Node remove() { _r.remove(); }
  Node get nextNode() => _r.nextNode; 

  Document get document() => _r.document;

  Node get previousNode() => _r.previousNode;

  String get text() => _r.text;
  void set text(String v) => _r.text;

  bool contains(Node other) => _r.contains(other);

  bool hasChildNodes() => _r.hasChildNodes();

  Node insertBefore(Node newChild, Node refChild) =>
    _r.insertBefore(newChild, refChild);

  AttributeMap get attributes() => _r.attributes;
  void set attributes(Map<String, String> value) {
    _r.attributes = value;
  }

  ElementList get elements() => _r.elements;

  void set elements(Collection<Element> value) {
    _r.elements = value;
  }

  Set<String> get classes() => _r.classes;

  void set classes(Collection<String> value) {
    _r.classes = value;
  }

  AttributeMap get dataAttributes() => _r.dataAttributes;
  void set dataAttributes(Map<String, String> value) {
    _r.dataAttributes = value;
  }

  Future<ElementRect> get rect() => r.rect;

  Future<CSSStyleDeclaration> get computedStyle() => r.computedStyle;

  Future<CSSStyleDeclaration> getComputedStyle(String pseudoElement)
    => r.getComputedStyle(pseudoElement);

  Element clone(bool deep) => _r.clone(deep);

  Element get parent() => _r.parent;

  ElementEvents get on() => _r.on;

  String get contentEditable() => _r.contentEditable;

  String get dir() => _r.dir;

  bool get draggable() => _r.draggable;

  bool get hidden() => _r.hidden;

  String get id() => _r.id;

  String get innerHTML() => _r.innerHTML;

  bool get isContentEditable() => _r.isContentEditable;

  String get lang() => _r.lang;

  String get outerHTML() => _r.outerHTML;

  bool get spellcheck() => _r.spellcheck;

  int get tabIndex() => _r.tabIndex;

  String get title() => _r.title;

  bool get translate() => _r.translate;

  String get webkitdropzone() => _r.webkitdropzone;

  void click() { _r.click(); }

  Element insertAdjacentElement(String where, Element element) =>
    _r.insertAdjacentElement(where, element);

  void insertAdjacentHTML(String where, String html) {
    _r.insertAdjacentHTML(where, html);
  }

  void insertAdjacentText(String where, String text) {
    _r.insertAdjacentText(where, text);
  }

  Map<String, String> get dataset() => _r.dataset;

  Element get nextElementSibling() => _r.nextElementSibling;

  Element get offsetParent() => _r.offsetParent;

  Element get previousElementSibling() => _r.previousElementSibling;

  CSSStyleDeclaration get style() => _r.style;

  String get tagName() => _r.tagName;
  String set tagName(String v) => _r.tagName = v;

  String get webkitRegionOverflow() => _r.webkitRegionOverflow;

  void blur() { _r.blur(); }

  void focus() { _r.focus(); }

  void scrollByLines(int lines) {
    _r.scrollByLines(lines);
  }

  void scrollByPages(int pages) {
    _r.scrollByPages(pages);
  }

  void scrollIntoView([bool centerIfNeeded]) {
    if (centerIfNeeded == null) {
      _r.scrollIntoView();
    } else {
      _r.scrollIntoView(centerIfNeeded);
    }
  }

  bool matchesSelector(String selectors) => _r.matchesSelector(selectors);

  void webkitRequestFullScreen(int flags) { _r.webkitRequestFullScreen(flags); }

  void webkitRequestFullscreen() { _r.webkitRequestFullscreen(); }

  void webkitRequestPointerLock() { _r.webkitRequestPointerLock(); }

  Element query(String selectors) => _r.query(selectors);

  List<Element> queryAll(String selectors) => _r.queryAll(selectors);
""";

Function _afterN(Function callback, int count) {
  return () {
    assert(count > 0);
    count--;
    if (count == 0) {
      callback();
    }
  };
}

/**
 * Locate all external component files, load each of them, expand
 * declarations and then launch a new isolate containing them.
 */
void loadComponents() {
  var declarations = <CustomElementDeclaration>[];

  var components = queryAll('link[rel=components]');

  var callback = _afterN(() { runComponents(declarations); }, components.length);
  for(var link in components) {
    var request = new HttpRequest();
    request
      ..open('GET', link.href, async: true)
      ..on.readyStateChange.add((Event e) {
        if (request.readyState == REQUEST_DONE) {
          try {
            if (request.status >= 200 && request.status < 300
                || request.status == 304 || request.status == 0) {
              declarations.add(new CustomElementDeclaration(link.href,
                                  new DocumentFragment.html(request.response)));
            } else {
              window.console.error(
                  'Unable to load component: Status ${request.status}'
                  ' - ${request.statusText}');
            }
          } finally {
            callback();
          }
        }
      })
      ..send();
  }
}

/// Declaration defining one or more custom elements.
class CustomElementDeclaration {
   /// Url the declaration was loaded from.
  final String url;
  /**
   * Html containing all custom element definitions specified as part of the
   * script.
   */
  final Element html;

  CustomElementDeclaration(this.url, this.html);
}

/// Build up a dart file that when executed laads all components on the page.
void runComponents(List<CustomElementDeclaration> declarations) {
  var sbHeader = new StringBuffer();
  var sb = new StringBuffer()
    ..add("""
#import("dart:html");
#import("$POLYFILL_LIBRARY_PACKAGE", prefix: "polyfill");
""");

  var sbMain = new StringBuffer()..add("void main() {");

  for(CustomElementDeclaration declaration in declarations) {
    var sbLibrary = new StringBuffer();
    var sbLibraryHeader = new StringBuffer();

    var topLevelScripts = declaration.html.queryAll('script').filter(
        (Element e) => e.parent.tagName != "ELEMENT");
    // For simplicity we assume at most one top level script.
    assert(topLevelScripts.length <= 1);
    for (ScriptElement script in topLevelScripts) {
      sbLibraryHeader
        ..add(script.text)
        ..add("\n");
    }

    String libraryName =
        const RegExp(@"([^/.]+)([^/]+)$").firstMatch(
            new Uri(declaration.url).path).group(1);
    sbLibrary
      ..add('#library("$libraryName");\n')
      ..add('#import("$POLYFILL_LIBRARY_PACKAGE", prefix: "polyfill");\n')
      ..add(sbLibraryHeader)..add("\n");


    int numDartCustomElements = 0;
    for(Element element in declaration.html.queryAll('element')) {
      String tag = element.attributes['name'];
      String className = element.attributes['constructor'];

      bool applyAuthorStyles = element.attributes.containsKey(
          'apply-author-styles');
      if (tag == null || tag.length == 0) {
        // TODO(samhop): friendlier errors
        window.console.error('name attribute is required');
        continue;
      }
      var extendz = element.attributes['extends'];
      if (extendz == null || extendz.length == 0) {
        window.console.error('extends attribute is required');
        continue;
      }
      if (className == null || className.length == 0) {
        // TODO(jacobr): relax this requirement.
        window.console.error('constructor attribute required for now');
        continue;
      }
      Element template = element.query('template');
      Element script = element.query('script[type="application/dart"]');
      if (script == null) {
        // TODO(jacobr): relax this requirement.
        window.console.warn("Skipped $className as no script body specified");
        continue;
      }
      numDartCustomElements++;
      var classBody = script.text;
      sbLibrary.add("""
class $className extends polyfill.WebComponent implements ${_tagToClassName[extendz]} {
  
  // Raw element the component is associated with.
  final Element _r;
  
  $className(this._r);

$classBody

$PROXY_ELEMENT_MEMBERS
}

// TODO(jacobr): support more than one component per library.
void register() {
  polyfill.registerComponent(new polyfill.CustomDeclaration("$tag", "$extendz",
      new Element.html(@'''${template.outerHTML}'''),
      true, "$className"));
}
""");

    }
    if (numDartCustomElements == 0) continue;

    var dataUrl =
        "data:application/dart;base64,${window.btoa(sbLibrary.toString())}";

    sb.add('#import(@"""$dataUrl""", prefix: "$libraryName");\n');
    sbMain.add("  ${libraryName}.register();\n");

    // TODO(jacobr): remove this once b/4344 is fixed. This script tag is
    // inserted into the page to make the debugging experience tollerable.
   document.head.nodes
    .add(
      new ScriptElement()
        ..text = """
$sbLibrary

void main() {
  print("Test that the library compiles. ignore.");
}
"""
        ..type = "application/dart");

  }
  sb.add("""
$sbMain
  polyfill.initializeComponents();
}
""");

  // Inject the output dart script on the page and the dart.js bootstrap script.
  document.head.nodes
   ..add(
     new ScriptElement()
       ..text = "$sb"
       ..type = "application/dart")
    ..add(
      new ScriptElement()
        ..src = "//dart.googlecode.com/svn/branches/bleeding_edge/dart/client/dart.js"
        ..type = "application/javascript");

}

void main() {
  loadComponents();
}
