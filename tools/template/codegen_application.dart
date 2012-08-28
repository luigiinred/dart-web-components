// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('codegen_application');

#import('dart:coreimpl');
#import('../../lib/html5parser/tokenkind.dart');
#import('../../lib/html5parser/htmltree.dart');
#import('../css/css.dart', prefix:'css');
#import('../lib/world.dart');
#import('codegen.dart');
#import('compile.dart');
#import('utils.dart');

/** Support routines to generate Dart code. */
class CodegenApplication {
  static CodegenApplication _cga = const CodegenApplication();

  const CodegenApplication();

  /*
   * [filename] passed in would be filename part (sans '.extension').
   */
  static String generate(int parentsPathCount, String libraryName,
                         String filename, ElemCG ecg) {
    // TODO(terry): Validate that the filename matches identifier:
    //              a..z || A..Z || _ [a..z || A..Z || 0..9 || _]*
    if (libraryName.indexOf('.') >= 0) {
      world.fatal("Bad library - $libraryName");
    }

    StringBuffer buff = new StringBuffer();
    int injectId = 0;         // Inject function id

    buff.add(Codegen.header(filename, libraryName, parentsPathCount));

    String buildHTML = ecg.applicationCodeBody();
    String body = "\n    var frag = new DocumentFragment();$buildHTML";
    buff.add(_cga._emitApplicationClass("MyApplication", body, "MyTemplate"));

    int idx = 1;
    CGBlock cgb;
    while ((cgb = ecg.templateCG(idx++)) != null) {
      int boundElementCount = cgb.boundElementCount;
      // Top-level template.
      // TODO(terry): Hard coded class name should use constructor attr?
      buff.add(_cga._emitTemplateClass("MyTemplate",
          boundElementCount,
          "    DocumentFragment templateRoot = new DocumentFragment();\n${
          cgb.codeBody}${Codegen.renderNodes}",
          templateExprFuncs: cgb.templatesCodeBody(ecg.expressions),
          injectFuncs: Codegen.injectionsCode(ecg)));
    }

    return buff.toString();
  }

  String _emitApplicationClass(String genClassName, String construcBody,
                                      String templateClassName) {
    List<String> myFuncs = [
      "Template createTemplate(var templateParent) => new ${
        templateClassName}(controller, templateParent);",
    ];
    return Codegen.emitClass(genClassName, 'Application',
        params: 'var controller',
        initializer: 'super(controller)',
        body: construcBody,
        funcs: myFuncs);
  }

  String _emitTemplateClass(String genClassName,
                                   int boundElementCount,
                                   String renderBody,
                                   [String templateExprFuncs = "",
                                    String injectFuncs = ""]) {
    StringBuffer buff = new StringBuffer();
    int i = 0;
    while (i < boundElementCount) {
      buff.add("\n    boundElements.add(new BoundElementEntry(templateLine_${
          i++}));");
    }

    List<String> myFuncs = [
      "void render() {\n$renderBody\n  }",
    ];
    return Codegen.emitClass(genClassName, "Template",
        params: 'var ctrl, Element parent',
        initializer: 'super(ctrl, parent)',
        body: buff.toString(),
        funcs: myFuncs,
        epilog: "${templateExprFuncs}$injectFuncs");
  }

  String _emitCSSSelectors(css.Stylesheet stylesheet) {
    if (stylesheet == null) {
      return "";
    }

    SplayTreeMap<String, css.CssData> classes;

    for (final production in stylesheet.topLevels) {
      if (production is css.IncludeDirective) {
        for (final topLevel in production.styleSheet.topLevels) {
          if (topLevel is css.RuleSet) {
            classes = css.Generate.computeClassSelectors(topLevel, classes);
          }
        }
      } else if (production is css.RuleSet) {
        classes = css.Generate.computeClassSelectors(production, classes);
      }
    }

    if (classes == null) {
      classes = new SplayTreeMap<String, css.CssData>();
    }

    var buff = new StringBuffer();
    for (final String knownClass in classes.getKeys()) {
      var dartName = toCamelCase(knownClass);
      buff.add("  static String get ${dartName}() => \"${knownClass}\";\n");
    }

    return buff.toString();
  }
}
