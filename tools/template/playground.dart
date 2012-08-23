// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This is a browser based developer playground that exposes an interactive
 * editor to create a template, parse and generate the Dart code.  The
 * playground displays the parse tree and the generated Dart code.  It is a dev
 * tool for the developers of this template compiler.  Normal use of this
 * compiler would be from the Dart VM command line running tool.dart.
 */

#import('dart:html');
#import('../../lib/html5parser/htmltree.dart');
#import('../lib/file_system_memory.dart');
#import('../lib/world.dart');
#import('../lib/source.dart');
#import('../lib/cmd_options.dart');
#import('template.dart');
#import('compile.dart');
#import('codegen.dart');
#import('compilation_unit.dart');

String currSampleTemplate;

void changeTemplate() {
  final Document doc = window.document;
  final SelectElement samples = doc.query('#templateSamples');
  final TextAreaElement template = doc.query('#template');
  template.value = sample(samples.value);
}

String sample(String sampleName) {
  final String each = '\${#each';
  final String endEach = '\${/each}';
  final String with = '\${#with';
  final String endWith = '\${/with}';

  final String simpleTemplate = @'''
<html>
  <head>
    <title>Forms Validation</title>
  </head>
  <body data-controller="FormController">
    <form>
      <template instantiate>
        <button disabled="{{ invalid }}">Submit</button><br>
        Email: <input type="text" value="{{ email }}" autofocus="autofocus"><br>
        Repeat Email: <input type="text" value="{{ repeatEmail }}"><br>
        <input type="checkbox" checked="{{ agree }}"> I agree<br>
        <button disabled="{{ invalid }}">Submit</button>
      </template>
    </form>
  </body>
</html>
  ''';

  switch (sampleName) {
    case "simple":
      return simpleTemplate;
    default:
      print("ERROR: Unknown sample template");
  }
}

void runTemplate([bool debug = false, bool parseOnly = false]) {
  final Document doc = window.document;
  final TextAreaElement dartClass = doc.query("#dart");
  final TextAreaElement template = doc.query('#template');
  final TableCellElement validity = doc.query('#validity');
  final TableCellElement result = doc.query('#result');

  bool templateValid = true;
  StringBuffer dumpTree = new StringBuffer();
  StringBuffer code = new StringBuffer();
  String htmlTemplate = template.value;

  if (debug) {
    try {
      var fs = new MemoryFileSystem();
      fs.writeString("_memory", htmlTemplate);

      var analyze = new Compile.memory(fs, "_memory", 2);

      analyze.forEach((CompilationUnit cu) {
        dumpTree.add(cu.document.toDebugString());

        // Get the generated Dart class for this template file.
        code.add(cu.code);
      });
    } catch (final htmlException) {
      // TODO(terry): TBD
      print("ERROR unhandled EXCEPTION");
    }
  }

  final bgcolor = templateValid ? "white" : "red";
  final color = templateValid ? "black" : "white";
  final valid = templateValid ? "VALID" : "NOT VALID";
  String resultStyle = "margin: 0; height: 100%; width: 100%;"
    "padding: 5px 7px;";

  result.innerHTML = '''
    <textarea style="${resultStyle}">${dumpTree.toString()}</textarea>
  ''';

  dartClass.value = code.toString();
}

void main() {
  final element = new Element.tag('div');

  element.innerHTML = '''
    <table style="width: 100%; height: 600px;">
      <tbody>
        <tr>
          <td style="vertical-align: top; width: 50%; padding-right: 25px;">
            <table style="height: 100%; width: 100%;" cellspacing=0 cellpadding=0 border=0>
              <tbody>
                <tr style="vertical-align: top; height: 1em;">
                  <td>
                    <span style="font-weight:bold;">Generated Dart</span>
                  </td>
                </tr>
                <tr>
                  <td>
                    <textarea id="dart" style="resize: none; width: 100%; height: 100%; padding: 5px 7px;"></textarea>
                  </td>
                </tr>
              </tbody>
            </table>
          </td>
          <td style="padding-right: 20px;">
            <table style="width: 100%; height: 100%;" cellspacing=0 cellpadding=0 border=0>
              <tbody>
                <tr style="vertical-align: top; height: 50%;">
                  <td>
                    <table style="width: 100%; height: 100%;" cellspacing=0 cellpadding=0 border=0>
                      <tbody>
                        <tr>
                          <td>
                            <span style="font-weight:bold;">HTML Template</span>
                          </td>
                        </tr>
                        <tr style="height: 100%;">
                          <td>
                            <textarea id="template" style="resize: none; width: 100%; height: 250px; padding: 5px 7px;">${sample("simple")}</textarea>
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
                            <button id=generate>Generate</button>
                          </td>
                          <td align="right">
                            <select id=templateSamples>
                              <option value="simple">Simple Template</option>
                            </select>
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
                            <span style="font-weight:bold;">Parse Tree</span>
                          </td>
                        </tr>
                        <tr style="vertical-align: top; height: 1em;">
                          <td id="validity">
                          </td>
                        </tr>
                        <tr>
                          <td id="result">
                            <textarea style="width: 100%; height: 100%; border: black solid 1px; padding: 5px 7px;"></textarea>
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

  ButtonElement genElem = window.document.query('#generate');
  genElem.on.click.add((MouseEvent e) {
    runTemplate(true, true);
  });

  SelectElement cannedTemplates = window.document.query('#templateSamples');
  cannedTemplates.on.change.add((e) {
    changeTemplate();
  });

  initHtmlWorld(parseOptions(commandOptions().parse([]), null));

  // Don't display any colors in the UI.
  options.useColors = false;

  // Replace error handler bring up alert for any problems.
  world.printHandler = (String msg) {
    window.alert(msg);
  };
}
