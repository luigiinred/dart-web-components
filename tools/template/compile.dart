// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('analysis');

#import('dart:coreimpl');
#import('../../lib/html5parser/tokenkind.dart');
#import('../../lib/html5parser/htmltree.dart');
#import('../css/css.dart', prefix:'css');
#import('../lib/file_system.dart');
#import('../lib/world.dart');
#import('codegen.dart');
#import('compilation_unit.dart');
#import('processor.dart');
#import('template.dart');
#import('utils.dart');


/**
 * Walk the tree produced by the parser looking for templates, expressions, etc.
 * as a prelude to emitting the code for the template.
 */
class Compile {
  final FileSystem fs;
  final String baseDir;
  final ProcessFiles components;

  // TODO(terry): Hacky use package: when we're part of the SDK.
  /** Number of ../ to find dart-web-components directory. */
  final int _parentsPathCount;

  /** Used by template tool to open a file. */
  Compile(FileSystem filesystem, String path, String filename, int parentsCnt)
      : fs = filesystem,
        baseDir = path,
        _parentsPathCount = parentsCnt,
        components = new ProcessFiles() {
    components.add(filename, CompilationUnit.TYPE_MAIN);
    _compile();
  }

  /** Used by playground to analyze a memory buffer. */
  Compile.memory(FileSystem filesystem, String filename, int parentsCnt)
      : fs = filesystem,
        baseDir = "",
        _parentsPathCount = parentsCnt,
        components = new ProcessFiles() {
    components.add(filename, CompilationUnit.TYPE_MAIN);
    _compile();
  }

  /**
   * All compiler work start here driven by the files processor.
   */
  void _compile() {
    var process;
    while ((process = components.nextProcess()) != ProcessFile.NULL_PROCESS) {
      if (!process.isProcessRunning) {
        // No process is running; so this is the next process to run.
        process.toProcessRunning();

        switch (process.phase) {
          case ProcessFile.PARSING:
            // Parse the template.
            String source = fs.readAll("$baseDir/${process.cu.filename}");

            final parsedElapsed = time(() {
              process.cu.document = templateParseAndValidate(source);
            });
            if (options.showInfo) {
              printStats("Parsed", parsedElapsed, process.cu.filename);
            }
            break;
          case ProcessFile.WALKING:
            // Walk the tree.
            final walkedElapsed = time(() {
              _walkTree(process.cu.document, process.cu.elemCG);
            });
            if (options.showInfo) {
              printStats("Walked", walkedElapsed, process.cu.filename);
            }
            break;
          case ProcessFile.ANALYZING:
            // Find next process to analyze.

            // TODO(terry): All analysis should be done here.  Today analysis
            //              is done in both ElemCG and CBBlock; these analysis
            //              parts should be moved into the Analyze class.  The
            //              tree walker portion should be a separate class that
            //              just does tree walking and produce the object graph
            //              that is intermingled with CGBlock, ElemCG and the
            //              CGStatement classes.

            // TODO(terry): The analysis phase not implemented.

            if (options.showInfo) {
              printStats("Analyzed", 0, process.cu.filename);
            }
            break;
          case ProcessFile.EMITTING:
            // Spit out the code for this file processed.
            final codegenElapsed = time(() {
              process.cu.code = _startEmitter(process);
            });
            if (options.showInfo) {
              printStats("Codegen", codegenElapsed, process.cu.filename);
            }
            break;
          default:
            world.error("Unexpected process $process");
            return;
        }

        // Signal this process has completed running for this phase.
        process.toProcessDone();
      }
    }
  }

  /** Walk the HTML tree of the template file. */
  void _walkTree(HTMLDocument doc, ElemCG ecg) {
    if (!ecg.pushBlock()) {
      world.error("Error at ${doc.children}");
    }

    var start;
    // Skip the fragment (root) if it exist and the HTML node as well.
    if (doc.children.length > 0 && doc.children[0] is HTMLElement) {
      HTMLElement elem = doc.children[0];
      if (elem.isFragment) {
        start = elem;
        for (var child in start.children) {
          if (child is HTMLText) {
            continue;
          } else if (child is HTMLElement) {
            if (child.tagTokenId == TokenKind.HTML_ELEMENT) {
              start = child;
            }
            break;
          }
        }
      }
    } else {
      start = doc;
    }

    bool firstTime = true;
    for (var child in start.children) {
      if (child is HTMLText) {
        if (!firstTime) {
          ecg.closeStatement();
        }

        // Skip any empty text nodes; no need to pollute the pretty-printed
        // HTML.
        // TODO(terry): Need to add {space}, {/r}, etc. like Soy.
        String textNodeValue = child.value.trim();
        if (textNodeValue.length > 0) {
          CGStatement stmt = ecg.pushStatement(child, "frag");
        }
        continue;
      }

      ecg.emitConstructHtml(child, "", "frag");
      firstTime = false;
    }
  }

  /** Emit the Dart code. */
  String _startEmitter(ProcessFile process) {
    CompilationUnit cu = process.cu;
    String libraryName = cu.filename.replaceAll('.', '_');

    return Codegen.generate(cu.document, _parentsPathCount, libraryName,
        cu.filename, cu.elemCG);
  }

  /**
   * Helper function to iterate throw all compilation units used by the tool
   * to write out the results of the compile.
   */
  void forEach(void f(CompilationUnit cu)) {
    components.forEach((ProcessFile pf) {
      f(pf.cu);
    });
  }
}


/**
 * CodeGen block used for a set of statements to be emited wrapped around a
 * template control that implies a block (e.g., iterate, with, etc.).  The
 * statements (HTML) within that block are scoped to a CGBlock.
 */
class CGBlock {
  /** Code type of this block. */
  final int _blockType;

  /** Number of spaces to prefix for each statement. */
  final int _indent;

  /** Optional local name for #each or #with. */
  final String _localName;

  final List<CGStatement> _stmts;

  /** Local variable index (e.g., e0, e1, etc.). */
  int _localIndex;

  // Block Types:
  static final int CONSTRUCTOR = 0;
  static final int REPEAT = 1;
  static final int TEMPLATE = 2;

  CGBlock([int indent = 4, int blockType = CGBlock.CONSTRUCTOR, local])
      : _stmts = new List<CGStatement>(),
        _localIndex = 0,
        _indent = indent,
        _blockType = blockType,
        _localName = local {
    assert(_blockType >= CGBlock.CONSTRUCTOR && _blockType <= CGBlock.TEMPLATE);
  }

  bool get hasStatements() => !_stmts.isEmpty();
  bool get isConstructor() => _blockType == CGBlock.CONSTRUCTOR;
  bool get isRepeat() => _blockType == CGBlock.REPEAT;
  bool get isTemplate() => _blockType == CGBlock.TEMPLATE;

  bool get hasLocalName() => _localName != null;
  String get localName() => _localName;

  /**
   * Each statement (HTML) encountered is remembered with either/both variable
   * name of parent and local name to associate with this element when the DOM
   * constructed.
   */
  CGStatement push(var elem, var parentName, [bool exact = false]) {
    var varName;
    if (elem is HTMLElement && elem.hasVar) {
      varName = elem.varName;
    } else {
      varName = _localIndex++;
    }

    CGStatement stmt = new CGStatement(elem, _indent, parentName, varName,
        exact, isRepeat);
    _stmts.add(stmt);

    return stmt;
  }

  void add(String value) {
    if (_stmts.last() != null) {
      _stmts.last().add(value);
    }
  }

  CGStatement get last() => _stmts.length > 0 ? _stmts.last() : null;

  /**
   * Returns mixed list of elements marked with the var attribute.  If the
   * element is inside of a #each the name exposed is:
   *
   *      List varName;
   *
   * otherwise it's:
   *
   *      var varName;
   *
   * TODO(terry): For scalars var varName should be Element tag type e.g.,
   *
   *                   DivElement varName;
   */
  String get globalDeclarations() {
    StringBuffer buff = new StringBuffer();
    for (final CGStatement stmt in _stmts) {
      buff.add(stmt.globalDeclaration());
    }

    return buff.toString();
  }

  int get boundElementCount() {
    int count = 0;
    if (isTemplate) {
      for (var stmt in _stmts) {
        if (stmt.hasTemplateExpression) {
          count++;
        }
      }
    }
    return count;
  }

  // TODO(terry): Need to update this when iterate is driven from the
  //             <template iterate='name in names'>.  Nested iterates are
  //             a List<List<Elem>>.
  /**
   * List of statement constructors for each var inside a #each.
   *
   *    ${#each products}
   *      <div var=myVar>...</div>
   *    ${/each}
   *
   * returns:
   *
   *    myVar = [];
   */
  String get globalInitializers() {
    StringBuffer buff = new StringBuffer();
    for (final CGStatement stmt in _stmts) {
      buff.add(stmt.globalInitializers());
    }

    return buff.toString();
  }

  String get codeBody() {
    StringBuffer buff = new StringBuffer();

    // If statement is a bound element, has {{ }}, then boundElemIdx will match
    // the BoundElementEntry index associated with this element's statement.
    int boundElemIdx = 0;
    for (final CGStatement stmt in _stmts) {
      buff.add(stmt.emitStatement(boundElemIdx));
      if (stmt.hasTemplateExpression) {
        boundElemIdx++;
      }
    }

    return buff.toString();
  }

  static String genBoundElementsCommentBlock = @"""


  // ==================================================================
  // Tags that contains a template expression {{ nnnn }}.
  // ==================================================================""";

  String templatesCodeBody(List<String> expressions) {
    StringBuffer buff = new StringBuffer();

    buff.add(genBoundElementsCommentBlock);

    int boundElemIdx = 0;   // Index if statement is a bound elem has a {{ }}.
    for (final CGStatement stmt in _stmts) {
      if (stmt.hasTemplateExpression) {
        buff.add(stmt.emitBoundElementFunction(expressions, boundElemIdx++));
      }
    }

    return buff.toString();
  }
}

// TODO(terry): Consider adding backpointer to block CGStatement is contained
//              in; no need to replicate things like whether the statement is
//              in a repeat block (e.g., _repeating).
/**
 * CodeGen Statement used to manage each statement to be emited.  CGStatement
 * has the HTML (_elem) as well as the variable name of the parent element and
 * the varName (variable name) to be used to create this DOM element.
 */
class CGStatement {
  final bool _repeating;
  final StringBuffer _buff;
  var _elem;
  int _indent;
  var parentName;
  String varName;
  bool _globalVariable;
  bool _closed;

  CGStatement(this._elem, this._indent, this.parentName, varNameOrIndex,
      [bool exact = false, bool repeating = false]) :
        _buff = new StringBuffer(),
        _closed = false,
        _repeating = repeating {

    if (varNameOrIndex is String) {
      // We have the global variable name
      varName = varNameOrIndex;
      _globalVariable = true;
    } else {
      // local index generate local variable name.
      varName = "e${varNameOrIndex}";
      _globalVariable = false;
    }
  }

  bool get hasGlobalVariable() => _globalVariable;
  String get variableName() => varName;

  String globalDeclaration() {
    if (hasGlobalVariable) {
      String spaces = Codegen.spaces(_indent);
      return (_repeating) ?
        "  List ${varName};    // Repeated elements.\n" : "  var ${varName};\n";
    }

    return "";
  }

  String globalInitializers() {
    if (hasGlobalVariable && _repeating) {
      return "    ${varName} = [];\n";
    }

    return "";
  }

  void add(String value) {
    _buff.add(value);
  }

  bool get closed() => _closed;

  void close() {
    if (_elem is HTMLElement && _elem.scoped) {
      add("</${_elem.tagName}>");
    }
    _closed = true;
  }

  String emitStatement(int boundElemIdx) {
    StringBuffer statement = new StringBuffer();

    String spaces = Codegen.spaces(_indent);

    String localVar = "";
    String tmpRepeat;
    if (hasGlobalVariable) {
      if (_repeating) {
        tmpRepeat = "tmp_${varName}";
        localVar = "var ";
      }
    } else {
      localVar = "var ";
    }

    /* Emiting the following code fragment where varName is the attribute
       value for var=

          varName = new Element.html('HTML GOES HERE');
          parent.nodes.add(varName);

       for repeating elements in a #each:

          var tmp_nnn = new Element.html('HTML GOES HERE');
          varName.add(tmp_nnn);
          parent.nodes.add(tmp_nnn);

       for elements w/o var attribute set:

          var eNNN = new Element.html('HTML GOES HERE');
          parent.nodes.add(eNNN);
    */
    if (hasTemplateExpression) {
      List<String> exprs = attributesExpressions();
      // TODO(terry): Need to handle > one attribute expression per line.
      statement.add("\n$spaces${
        localVar}$varName = renderSetupFineGrainUpdates(() => model.${
        exprs[0]}, $boundElemIdx);");
    } else {
      bool isTextNode = _elem is HTMLText;
      String createType = isTextNode ? "Text" : "Element.html";
      if (tmpRepeat == null) {
        statement.add("\n$spaces$localVar$varName = new $createType(\'");
      } else {
        statement.add(
            "\n$spaces$localVar$tmpRepeat = new $createType(\'");
      }
      if (_elem is Template) {
        statement.add("<template></template>");
      } else {
        statement.add(isTextNode ?
            _buff.toString().trim() : _buff.toString());
      }
      statement.add("\');");
    }

    if (tmpRepeat == null) {
      statement.add("\n$spaces$parentName.nodes.add($varName);");
      if (_elem is Template) {
        // TODO(terry): Need to support multiple templates either nested or
        //              siblings.
        // Hookup Template to the root.
        statement.add("\n${spaces}root = $parentName;");
      }
    } else {
      statement.add("\n$spaces$parentName.nodes.add($tmpRepeat);");
      statement.add("\n$spaces$varName.add($tmpRepeat);");
    }

    return statement.toString();
  }

  String emitBoundElementFunction(List<String> expressions, int index) {
    // Statements to update attributes associated with expressions.
    StringBuffer statementUpdateAttrs = new StringBuffer();

    StringBuffer statement = new StringBuffer();

    String spaces = Codegen.spaces(2);

    statement.add("\n${spaces}Element templateLine_$index(var e0) {\n");
    statement.add("$spaces  if (e0 == null) {\n");

    // Creation of DOM element.
    bool isTextNode = _elem is HTMLText;
    String createType = isTextNode ? "Text" : "Element.html";
    statement.add("$spaces    e0 = new $createType(\'");
    statement.add(isTextNode ? _buff.toString().trim() : _buff.toString());
    statement.add("\');\n");

    // TODO(terry): Fill in event hookup this is hacky.
    if (_elem.attributes != null) {
      for (var attr in _elem.attributes) {
        if (attr is TemplateAttributeExpression) {
          int idx = expressions.indexOf(attr.value);
          assert(idx != -1);

          if (_elem.tagTokenId == TokenKind.INPUT_ELEMENT) {
            if (attr.name == "value") {
              // Hook up on keyup.
              statement.add("$spaces    e0.on.keyUp.add(wrap1((_) { model.${
                  attr.value} = e0.value; }));\n");
            } else if (attr.name == "checked") {
              statement.add("$spaces    e0.on.click.add(wrap1((_) { model.${
                  attr.value} = e0.checked; }));\n");
            } else {
              // TODO(terry): Need to handle here with something...
              // data-on-XXXXX would handle on-change .on.change.add(listener);

//              assert(false);
            }
          }

          statementUpdateAttrs.add(
              "$spaces  e0.${attr.name} = inject_$idx();\n");
        }
      }
    }

    statement.add("$spaces  }\n");

    statement.add(statementUpdateAttrs.toString());

    statement.add("$spaces  return e0;\n");
    statement.add("$spaces}\n");

    return statement.toString();
  }

  bool get hasTemplateExpression() {
    if (_elem is HTMLElement && _elem.attributes != null) {
      int count = _elem.attributes.length;
      int idx = 0;
      while (idx < count) {
        if (_elem.attributes[idx++] is TemplateAttributeExpression) {
          return true;
        }
      }
    }

    return false;
  }

  /** Find all attributes associated with a template expression. */
  List<String> attributesExpressions() {
    List<String> result = new List<String>();

    if (_elem is HTMLElement && _elem.attributes != null) {
      for (var attr in _elem.attributes) {
        if (attr is TemplateAttributeExpression) {
          result.add(attr.value);
        }
      }
    }

    return result;
  }

}


// TODO(terry): Consider merging ElemCG and Analyze.
/**
 * Code that walks the HTML tree.
 */
class ElemCG {
  // TODO(terry): Hacky, need to replace with real expression parser.
  /** List of identifiers and quoted strings (single and double quoted). */
  var identRe = const RegExp(
      @"""s*('"\'\"[^'"\'\"]+'"\'\"|[_A-Za-z][_A-Za-z0-9]*)""");

  bool _webComponent;

  /** Name of class if web component constructor attribute of element tag. */
  String _className;

  /** List of script tags with src. */
  final List<String> _includes;

  /** Dart script code associated with web component. */
  String _userCode;

  final List<CGBlock> _cgBlocks;

  /** Global var declarations for all blocks. */
  final StringBuffer _globalDecls;

  /** Global List var initializtion for all blocks in a #each. */
  final StringBuffer _globalInits;

  /** List of injection function declarations. */
  final List<String> _expressions;

  /**  List of each function declarations. */
  final List<String> repeats;

  /** List of web components to process <link rel=component>. */
  ProcessFiles processor;

  ElemCG(this.processor)
      : _webComponent = false,
        _includes = [],
        _expressions = [],
        repeats = [],
        _cgBlocks = [],
        _globalDecls = new StringBuffer(),
        _globalInits = new StringBuffer();

  bool get isWebComponent => _webComponent;
  String get className() => _className;
  List<String> get includes() => _includes;
  String get userCode() => _userCode;

  void reportError(String msg) {
    String filename = processor.current.cu.filename;
    world.error("$filename: $msg");
  }

  bool get isLastBlockConstructor() {
    CGBlock block = _cgBlocks.last();
    return block.isConstructor;
  }

  String applicationCodeBody() {
    return getCodeBody(0);
  }

  CGBlock templateCG(int index) {
    if (index > 0) {
      return getCGBlock(index);
    }
  }

  List<String> get expressions() => _expressions;

  List<String> activeBlocksLocalNames() {
    List<String> result = [];

    for (final CGBlock block in _cgBlocks) {
      if (block.isRepeat && block.hasLocalName) {
        result.add(block.localName);
      }
    }

    return result;
  }

  /**
   * Active block with this localName.
   */
  bool matchBlocksLocalName(String name) =>
      _cgBlocks.some((block) => block.isRepeat &&
                                block.hasLocalName &&
                                block.localName == name);

  /**
   * Any active blocks?
   */
  bool isNestedBlock() =>
      _cgBlocks.some((block) => block.isRepeat);

  /**
   * Any active blocks with localName?
   */
  bool isNestedNamedBlock() =>
      _cgBlocks.some((block) => block.isRepeat && block.hasLocalName);

  // Any current active #each blocks.
  bool anyRepeatBlocks() =>
      _cgBlocks.some((block) => block.isRepeat);

  bool pushBlock([int indent = 4, int blockType = CGBlock.CONSTRUCTOR,
                  String itemName = null]) {
    if (itemName != null && matchBlocksLocalName(itemName)) {
      reportError("Active block already exist with local name: ${itemName}.");
      return false;
    } else if (itemName == null && this.isNestedBlock()) {
      reportError('''
Nested iterates must have a localName;
 \n  #each list [localName]\n  #with object [localName]''');
      return false;
    }
    _cgBlocks.add(
        new CGBlock(indent, blockType, itemName));

    return true;
  }

  void popBlock() {
    _globalDecls.add(lastBlock.globalDeclarations);
    _globalInits.add(lastBlock.globalInitializers);
    _cgBlocks.removeLast();
  }

  CGStatement pushStatement(var elem, var parentName) {
    return lastBlock.push(elem, parentName);
  }

  bool get closedStatement() {
    return (lastBlock != null && lastBlock.last != null) ?
        lastBlock.last.closed : false;
  }

  void closeStatement() {
    if (lastBlock != null && lastBlock.last != null &&
        !lastBlock.last.closed) {
      lastBlock.last.close();
    }
  }

  String get lastVariableName() {
    if (lastBlock != null && lastBlock.last != null) {
      return lastBlock.last.variableName;
    }
  }

  String get lastParentName() {
    if (lastBlock != null && lastBlock.last != null) {
      return lastBlock.last.parentName;
    }
  }

  CGBlock get lastBlock() => _cgBlocks.length > 0 ? _cgBlocks.last() : null;

  void add(String str) {
    _cgBlocks.last().add(str);
  }

  String get globalDeclarations() {
    assert(_cgBlocks.length == 1);    // Only constructor body should be left.
    _globalDecls.add(lastBlock.globalDeclarations);
    return _globalDecls.toString();
  }

  String get globalInitializers() {
    assert(_cgBlocks.length == 1);    // Only constructor body should be left.
    _globalInits.add(lastBlock.globalInitializers);
    return _globalInits.toString();
  }

  CGBlock getCGBlock(int idx) => idx < _cgBlocks.length ? _cgBlocks[idx] : null;

  String getCodeBody(int index) {
    CGBlock cgb = getCGBlock(index);
    return (cgb != null) ? cgb.codeBody : lastCodeBody;
  }

  String get lastCodeBody() {
    closeStatement();
    return _cgBlocks.last().codeBody;
  }

  /**
   * Any element with this link tag:
   *     <link rel="component" href="webcomponent_file">
   * defines a web component file to process.
   */
  void queueUpFileToProcess(HTMLElement elem) {
    if (elem.tagTokenId == TokenKind.LINK_ELEMENT) {
      bool webComponent = false;
      String href = "";
      // TODO(terry): Consider making HTMLElement attributes a map instead of
      //              a list for faster access.
      for (HTMLAttribute attr in elem.attributes) {
        if (attr.name == 'rel' && attr.value == 'components') {
          webComponent = true;
        }
        if (attr.name == 'href') {
          href = attr.value;
        }
      }
      if (webComponent && !href.isEmpty()) {
        processor.add(href);
      }
    }
  }

  String getAttributeValue(HTMLElement elem, String name) {
    for (HTMLAttribute attr in elem.attributes) {
      if (attr.name.toLowerCase() == name) {
        return attr.value;
      }
    }

    return null;
  }

  final String _SCRIPT_TYPE_ATTR = "type";
  final String _SCRIPT_SRC_ATTR = "src";
  final String _DART_SCRIPT_TYPE = "application/dart";
  emitScript(HTMLElement elem) {
    Expect.isTrue(elem.tagTokenId == TokenKind.SCRIPT_ELEMENT);

    String typeValue = getAttributeValue(elem, _SCRIPT_TYPE_ATTR);
    if (typeValue != null && typeValue == _DART_SCRIPT_TYPE) {
      String includeName = getAttributeValue(elem, _SCRIPT_SRC_ATTR);
      if (includeName != null) {
        _includes.add(includeName);
      } else {
        Expect.isTrue(elem.children.length == 1);
        // This is the code to be emitted with the web component.
        _userCode = elem.children[0].toString();
      }
    } else {
      reportError("tag ignored possibly missing type='application/dart'");
    }
  }

  /**
   * [scopeName] for expression.
   * [parentVarOrIndex] if # it's a local variable if string it's an exposed
   * name (specified by the var attribute) for this element.
   */
  emitElement(var elem,
              [String scopeName = "",
               var parentVarOrIdx = 0,
               bool immediateNestedRepeat = false]) {
    if (elem is Template) {
      Template template = elem;
      emitTemplate(template, template.instantiate);
    } else if (elem is HTMLElement) {
      if (elem is HTMLUnknownElement) {
        HTMLUnknownElement unknownElem = elem;
        if (unknownElem.xTag == "element") {
          _webComponent = true;
          String className = getAttributeValue(unknownElem, "constructor");
          if (className != null) {
            _className = className;
          } else {
            reportError("Missing class name of Web Component use constructor attribute");
          }
        }
      } else if (elem.tagTokenId == TokenKind.SCRIPT_ELEMENT) {
        // Never emit a script tag.
        emitScript(elem);
      } else {
        if (!elem.isFragment) {
          add("<${elem.tagName}${elem.attributesToString(false)}>");
          queueUpFileToProcess(elem);
        }
        String prevParent = lastVariableName;
        for (var childElem in elem.children) {
          if (childElem is HTMLElement) {
            closeStatement();
            if (childElem.hasVar) {
              emitConstructHtml(childElem, scopeName, prevParent,
                childElem.varName);
            } else {
              emitConstructHtml(childElem, scopeName, prevParent);
            }
            closeStatement();
          } else {
            emitElement(childElem, scopeName, parentVarOrIdx);
          }
        }
      }

      // Close this tag.
      closeStatement();
    } else if (elem is HTMLText) {
      String outputValue = elem.value.trim();
      if (outputValue.length > 0) {
        bool emitTextNode = false;
        if (closedStatement) {
          String prevParent = lastParentName;
          CGStatement stmt = pushStatement(elem, prevParent);
          emitTextNode = true;
        }

        // TODO(terry): Need to interpolate following:
        //      {sp}  → space
        //      {nil} → empty string
        //      {\r}  → carriage return
        //      {\n}  → new line (line feed)
        //      {\t}  → tab
        //      {lb}  → left brace
        //      {rb}  → right brace

        add("${outputValue}");            // remove leading/trailing whitespace.

        if (emitTextNode) {
          closeStatement();
        }
      }
    } else if (elem is TemplateExpression) {
      emitExpressions(elem, scopeName);
    } else if (elem is TemplateCall) {
      emitCall(elem, parentVarOrIdx);
    }
  }

  // TODO(terry): Hack prefixing all names with "${scopeName}." but don't touch
  //              quoted strings.
  String _resolveNames(String expr, String prefixPart) {
    StringBuffer newExpr = new StringBuffer();
    Iterable<Match> matches = identRe.allMatches(expr);

    int lastIdx = 0;
    for (Match m in matches) {
      if (m.start() > lastIdx) {
        newExpr.add(expr.substring(lastIdx, m.start()));
      }

      bool identifier = true;
      if (m.start() > 0)  {
        int charCode = expr.charCodeAt(m.start() - 1);
        // Starts with ' or " then it's not an identifier.
        identifier = charCode != 34 /* " */ && charCode != 39 /* ' */;
      }

      String strMatch = expr.substring(m.start(), m.end());
      if (identifier) {
        newExpr.add("${prefixPart}.${strMatch}");
      } else {
        // Quoted string don't touch.
        newExpr.add("${strMatch}");
      }
      lastIdx = m.end();
    }

    if (expr.length > lastIdx) {
      newExpr.add(expr.substring(lastIdx));
    }

    return newExpr.toString();
  }

  // TODO(terry): Might want to optimize if the other top-level nodes have no
  //              control structures (with, each, if, etc.). We could
  //              synthesize a root node and create all the top-level nodes
  //              under the root node with one innerHTML.
  /**
   * Construct the HTML; each top-level node get's it's own variable.
   */
  void emitConstructHtml(var elem,
                         [String scopeName = "",
                          String parentName = "parent",
                          var varIndex = 0,
                          bool immediateNestedRepeat = false]) {
    if (elem is HTMLElement) {
      // Any TemplateAttributeExpression?
      if (elem.attributes != null) {
        for (var attr in elem.attributes) {
          if (attr is TemplateAttributeExpression) {
            emitAttributeExpression(attr);
          }
        }
      }

      CGStatement stmt = pushStatement(elem, parentName);
      emitElement(elem, scopeName, stmt.hasGlobalVariable ?
          stmt.variableName : varIndex);
    } else {
      // Text node.
      emitElement(elem, scopeName, varIndex, immediateNestedRepeat);
    }
  }

  /**
   * Any references to products.sales needs to be remaped to item.sales
   * for now it's a hack look for first dot and replace with item.
   */
  String repeatIterNameToItem(String iterName) {
    String newName = iterName;
    var dotForIter = iterName.indexOf('.');
    if (dotForIter >= 0) {
      newName = "_item${iterName.substring(dotForIter)}";
    }

    return newName;
  }

  void emitIncludes() {

  }

  void emitAttributeExpression(TemplateAttributeExpression elem) {
    if (_expressions.indexOf(elem.value) == -1) {
      _expressions.add(elem.value);
    }
  }

  void emitExpressions(TemplateExpression elem, String scopeName) {
    StringBuffer func = new StringBuffer();

    String newExpr = elem.expression;
    bool anyNesting = isNestedNamedBlock();
    if (scopeName.length > 0 && !anyNesting) {
      // In a block #command need the scope passed in.
      add("\$\{inject_${_expressions.length}(_item)\}");
      func.add("\n  String inject_${_expressions.length}(var _item) {\n");
      // Escape all single-quotes, this expression is embedded as a string
      // parameter for the call to safeHTML.
      newExpr = _resolveNames(newExpr.replaceAll("'", "\\'"), "_item");
    } else {
      // Not in a block #command item isn't passed in.
      add("\$\{inject_${_expressions.length}()\}");
      func.add("\n  String inject_${_expressions.length}() {\n");

      if (anyNesting) {
        func.add(defineScopes());
      }
    }

    // Construct the active scope names for name resolution.

    func.add("    return safeHTML('\$\{${newExpr}\}');\n");
    func.add("  }\n");

    _expressions.add(func.toString());
  }

  void emitCall(TemplateCall elem, String scopeName) {
    pushStatement(elem, scopeName);
  }

  void emitTemplate(Template elem, String instantiate) {
    if (!pushBlock(6, CGBlock.TEMPLATE)) {
      reportError("Error at ${elem}");
    }

    for (var child in elem.children) {
      emitConstructHtml(child, "e0", "templateRoot");
    }
  }

  String get lastBlockVarName() {
    var varName;
    if (lastBlock != null && lastBlock.hasStatements) {
      varName = lastBlock.last.variableName;
    } else {
      varName = "root";
    }

    return varName;
  }

  String injectParamName(String name) {
    // Local name _item is reserved.
    if (name != null && name == "_item") {
      return null;    // Local name is not valid.
    }

    return (name == null) ? "_item" : name;
  }

  addScope(int indent, StringBuffer buff, String item) {
    String spaces = Codegen.spaces(indent);

    if (item == null) {
      item = "_item";
    }
    buff.add("${spaces}_scopes[\"${item}\"] = ${item};\n");
  }

  removeScope(int indent, StringBuffer buff, String item) {
    String spaces = Codegen.spaces(indent);

    if (item == null) {
      item = "_item";
    }
    buff.add("${spaces}_scopes.remove(\"${item}\");\n");
  }

  String defineScopes() {
    StringBuffer buff = new StringBuffer();

    // Construct the active scope names for name resolution.
    List<String> names = activeBlocksLocalNames();
    if (names.length > 0) {
      buff.add("    // Local scoped block names.\n");
      for (String name in names) {
        buff.add("    var ${name} = _scopes[\"${name}\"];\n");
      }
      buff.add("\n");
    }

    return buff.toString();
  }

}
