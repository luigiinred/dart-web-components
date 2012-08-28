// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('css');

#import('dart:coreimpl');
#import('dart:math', prefix: 'Math');
#import('package:args/args.dart');
#import("../lib/file_system.dart");
#import('../lib/file_system_memory.dart');
#import('../lib/cmd_options.dart');
#import("../../lib/ui/styleimpl/styleimpl.dart");
#import('../lib/world.dart');
#import('../lib/source.dart');

#source('tokenkind.dart');
#source('token.dart');
#source('tokenizer_base.dart');
#source('tokenizer.dart');
#source('treebase.dart');
#source('tree.dart');
#source('cssselectorexception.dart');
#source('cssworld.dart');
#source('parser.dart');
#source('validate.dart');
#source('generate.dart');

ArgParser commandOptions() {
  // tool.dart [options...] <css file>
  var args = new ArgParser();
  args.addOption('out', help: 'Directory to generate .css and .dart file');
  args.addOption('gen', help: 'Name of library and base name of output files');
  args.addFlag('verbose', help: 'Display detail info', defaultsTo: false);
  args.addFlag('suppress_warnings', help: 'Warnings not displayed',
      defaultsTo: true);
  args.addFlag('warnings_as_errors', help: 'Warning handled as errors',
      defaultsTo: false);
  args.addFlag('throw_on_errors', help: 'Throw on errors encountered',
      defaultsTo: false);
  args.addFlag('throw_on_warnings', help: 'Throw on warnings encountered',
      defaultsTo: false);
  args.addFlag('no_colors', help: 'Display errors/warnings in colored text',
      defaultsTo: true);
  args.addFlag('help', help: 'Displays this help message', defaultsTo: false);

  return args;
}

void initCssWorld(CmdOptions opt) {
  FileSystem fs = new MemoryFileSystem();
  initializeWorld(fs, opt);
}

// TODO(terry): Add obfuscation mapping file.
void cssParseAndValidate(String cssExpression, CssWorld cssworld) {
  Parser parser = new Parser(new SourceFile(SourceFile.IN_MEMORY_FILE,
      cssExpression));
  var tree = parser.parseTemplate();
  if (tree != null) {
    Validate.template(tree.selectors, cssworld);
  }
}

/** Returns a pretty printed tree of the expression. */
String cssParseAndValidateDebug(String cssExpression, CssWorld cssworld) {
  Parser parser = new Parser(new SourceFile(SourceFile.IN_MEMORY_FILE,
      cssExpression));
  String output = "";
  String prettyTree = "";
  try {
    var tree = parser.parseTemplate();
    if (tree != null) {
      prettyTree = tree.toDebugString();
      Validate.template(tree.selectors, cssworld);
      output = prettyTree;
    }
  } catch (var e) {
    String error = e.toString();
    output = "$error\n$prettyTree";
    throw e;
  }

  return output;
}
