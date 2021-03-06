// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This is a browser based developer playground that exposes an interactive
 * editor to create CSS, parse and generate the CSS and Dart code.  The
 * playground displays the parse tree and the generated Dart code.  It is a dev
 * tool for the developers of this pre-processor.  Normal use of this tool
 * would be from the Dart VM command line running tool.dart.
 */

#import('dart:html');
#import('package:args/args.dart');
#import('../lib/file_system_memory.dart');
#import('../lib/source.dart');
#import('../lib/world.dart');
#import('../lib/cmd_options.dart');
#import('css.dart');

void runCss([bool debug = false, bool parseOnly = false,
    bool generateOnly = false]) {
  final TextAreaElement classes = document.query("#classes");
  final TextAreaElement expression = document.query('#expression');
  final TableCellElement validity = document.query('#validity');
  final TableCellElement result = document.query('#result');

  var knownWorld = classes.value.split("\n");
  var knownClasses = <String>[];
  var knownIds = <String>[];
  for (final name in knownWorld) {
    if (name.startsWith('.')) {
      knownClasses.add(name.substring(1));
    } else if (name.startsWith('#')) {
      knownIds.add(name.substring(1));
    }
  }

  CssWorld cssWorld = new CssWorld(knownClasses, knownIds);
  bool templateValid = true;
  String dumpTree = "";

  String cssExpr = expression.value;
  if (!debug) {
    try {
      cssParseAndValidate(cssExpr, cssWorld);
    } catch (final cssException) {
      templateValid = false;
      dumpTree = cssException.toString();
    }
  } else if (parseOnly) {
    try {
      Parser parser = new Parser(new SourceFile(
          SourceFile.IN_MEMORY_FILE, cssExpr));
      Stylesheet stylesheet = parser.parse();
      StringBuffer stylesheetTree = new StringBuffer();
      String prettyStylesheet = stylesheet.toString();
      stylesheetTree.add("${prettyStylesheet}\n");
      stylesheetTree.add("\n============>Tree Dump<============\n");
      stylesheetTree.add(stylesheet.toDebugString());
      dumpTree = stylesheetTree.toString();
    } catch (final cssParseException) {
      templateValid = false;
      dumpTree = cssParseException.toString();
    }
  } else if (generateOnly) {
    Parser parser = new Parser(new SourceFile(
      SourceFile.IN_MEMORY_FILE, cssExpr));

    String sourceFilename = "<IN MEMORY>";
    Stylesheet stylesheet = parser.parse();

    StringBuffer buff = new StringBuffer(
      '/* File generated by SCSS from source ${sourceFilename}\n'
      ' * Do not edit.\n'
      ' */\n\n');
    buff.add(stylesheet.toString());

    // Generate CSS.dart file.
    String genedClass = Generate.dartClass(stylesheet, sourceFilename,
        'sampleLib');
    buff.add(genedClass.toString());
    dumpTree = buff.toString();
  } else {
    try {
      dumpTree = cssParseAndValidateDebug(cssExpr, cssWorld);
    } catch (final cssException) {
      templateValid = false;
      dumpTree = cssException.toString();
    }
  }

  final bgcolor = templateValid ? "white" : "red";
  final color = templateValid ? "black" : "white";
  final valid = templateValid ? "VALID" : "NOT VALID";
  String resultStyle = "resize:both; margin:0; height:300px; width:98%;"
    "padding:5px 7px;";
  String validityStyle = "font-weight:bold; background-color:$bgcolor;"
    "color:$color; border:1px solid black; border-bottom:0px solid white;";
  validity.innerHTML = '''
    <div style="$validityStyle">
      Expression: $cssExpr is $valid
    </div>
  ''';
  result.innerHTML = "<textarea style=\"$resultStyle\">$dumpTree</textarea>";
}

void main() {
  final element = new Element.tag('div');
  element.innerHTML = '''
    <table style="width: 100%; height: 100%;">
      <tbody>
        <tr>
          <td style="vertical-align: top; width: 200px;">
            <table style="height: 100%;">
              <tbody>
                <tr style="vertical-align: top; height: 1em;">
                  <td>
                    <span style="font-weight:bold;">Classes</span>
                  </td>
                </tr>
                <tr style="vertical-align: top;">
                  <td>
                    <textarea id="classes" style="resize: none; width: 200px; height: 100%; padding: 5px 7px;">.foobar\n.xyzzy\n.test\n.dummy\n#myId\n#myStory</textarea>
                  </td>
                </tr>
              </tbody>
            </table>
          </td>
          <td>
            <table style="width: 100%; height: 100%;" cellspacing=0 cellpadding=0 border=0>
              <tbody>
                <tr style="vertical-align: top; height: 100px;">
                  <td>
                    <table style="width: 100%;">
                      <tbody>
                        <tr>
                          <td>
                            <span style="font-weight:bold;">Selector Expression</span>
                          </td>
                        </tr>
                        <tr>
                          <td>
                            <textarea id="expression" style="resize: both; width: 98%; height: 100px; padding: 5px 7px;"></textarea>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>

                <tr style="vertical-align: top; height: 50px;">
                  <td>
                    <table>
                      <tbody>
                        <tr>
                          <td>
                            <button id=parse>Parse</button>
                          </td>
                          <td>
                            <button id=check>Check</button>
                          </td>
                          <td>
                            <button id=generate>Generate</button>
                          </td>
                          <td>
                            <button id=debug>Debug</button>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>

                <tr style="vertical-align: top;">
                  <td>
                    <table style="width: 100%; height: 100%;" border="0" cellpadding="0" cellspacing="0">
                      <tbody>
                        <tr style="vertical-align: top; height: 1em;">
                          <td>
                            <span style="font-weight:bold;">Result</span>
                          </td>
                        </tr>
                        <tr style="vertical-align: top; height: 1em;">
                          <td id="validity">
                          </td>
                        </tr>
                        <tr style="vertical-align: top;">
                          <td id="result">
                            <textarea style="resize: both; width: 98%; height: 300px; border: black solid 1px; padding: 5px 7px;"></textarea>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
          </td>
        </tr>
      </tbody>
    </table>
  ''';

  document.body.style.setProperty("background-color", "lightgray");
  document.body.elements.add(element);

  ButtonElement parseButton = document.query('#parse');
  parseButton.on.click.add((MouseEvent e) {
    runCss(true, true);
  });

  ButtonElement checkButton = document.query('#check');
  checkButton.on.click.add((MouseEvent e) {
    runCss();
  });

  ButtonElement generateButton = document.query('#generate');
  generateButton.on.click.add((MouseEvent e) {
    runCss(true, false, true);
  });

  ButtonElement debugButton = document.query('#debug');
  debugButton.on.click.add((MouseEvent e) {
    runCss(true);
  });

  initCssWorld(parseOptions(commandOptions().parse([]), null));
}
