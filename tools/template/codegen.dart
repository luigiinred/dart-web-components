#library('codegen');

#import('dart:coreimpl');
#import('../../lib/html5parser/tokenkind.dart');
#import('../../lib/html5parser/htmltree.dart');
#import('../css/css.dart', prefix:'css');
#import('../lib/world.dart');
#import('compile.dart');
#import('utils.dart');

class Codegen {
  static final String SPACES = "                                              ";
  static String spaces(int numSpaces) {
    return SPACES.substring(0, numSpaces);
  }

  static String _fileHeader(String filename, String libraryName,
                        String parentsDotDot) => """
// Generated Dart class from HTML template $filename.
// DO NOT EDIT.

#library('${libraryName}');

#import('dart:html');
#import('${parentsDotDot}component.dart');
#import('${parentsDotDot}watcher.dart');
#import('${parentsDotDot}webcomponents.dart');
#import('${parentsDotDot}tools/lib/data_template.dart');

""";
  static String header(String filename, String libraryName, int parentsCount) {
    String parentsDotDot = "";
    while (parentsCount-- > 0) {
      parentsDotDot = "$parentsDotDot../";
    }
    return "${_fileHeader(filename, libraryName, parentsDotDot)}";
  }

  /**
   *  Epilog of the render function; injects the nodes into the live document
   *  to make everything visible.
   */
  static String renderNodes = @"""


    var nodes = templateRoot.nodes;
    while (nodes.length > 0) {
      parent.nodes.add(nodes[0]);
    }""";

  static String emitClass(String className,
                          String extendsName,
                          [String classBodyCode = null,
                           String params = null,
                           String initializer = null,
                           String body = null,
                           List<String> funcs = null,
                           String epilog = null]) {
    StringBuffer buff = new StringBuffer();
    buff.add(
        "\nclass $className extends $extendsName {\n");

    if (classBodyCode != null) {
      buff.add(classBodyCode);
    }

    bool constructParams = params != null && !params.isEmpty();
    buff.add("  $className(${constructParams ? params: ''}) ");

    bool constructInitializer = initializer != null && !initializer.isEmpty();
    buff.add("${constructInitializer ? ': $initializer' : ''}");

    bool constructBody = body != null && !body.isEmpty();
    buff.add("${constructBody ? ' {$body\n  }' : ';'}");

    bool anyFuncs = funcs != null && funcs.length > 0;
    if (anyFuncs) {
      for (String func in funcs) {
        if (func.trim().length > 0) {
          buff.add("\n\n");
          buff.add("  $func");
        }
      }
    }

    if (epilog != null && epilog.length > 0) {
      buff.add(epilog);
    }

    buff.add("\n}\n");

    return buff.toString();
  }

  static String genInjectsCommentBlock = @"""

  // ==================================================================
  // Injection functions:
  // ==================================================================""";

  static String injectionsCode(ecg) {
    StringBuffer buff = new StringBuffer();

    // Emit all injection functions.
    buff.add(genInjectsCommentBlock);
    var index = 0;
    for (var expr in ecg.expressions) {
      buff.add("\n  inject_$index() => safeHTML(model.$expr);");
      index++;
    }

    return buff.toString();
  }

}
