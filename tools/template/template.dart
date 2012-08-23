// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('template');

#import('dart:coreimpl');
#import('package:args/args.dart');
#import('../../lib/html5parser/parser.dart');
#import('../../lib/html5parser/htmltree.dart');
#import('../lib/cmd_options.dart');
#import('../lib/file_system_memory.dart');
#import('../lib/source.dart');
#import('../lib/cmd_options.dart');
#import('../lib/world.dart');
#import('compile.dart');
#import('codegen.dart');
#import('utils.dart');

ArgParser commandOptions() {
  var args = new ArgParser();
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

void initHtmlWorld(CmdOptions opts) {
  var fs = new MemoryFileSystem();
  initializeWorld(fs, opts);

  // TODO(terry): Should be set by arguments.  When run as a tool these aren't
  // set when run internaly set these so we can compile CSS and catch any
  // problems programmatically.
  //  options.throwOnErrors = true;
  //  options.throwOnFatal = true;
  //  options.useColors = commandLine ? true : false;
}

// TODO(terry): Add obfuscation mapping file.
HTMLDocument templateParseAndValidate(String template) {
  Parser parser = new Parser(new SourceFile(SourceFile.IN_MEMORY_FILE,
    template));

  return parser.parse();
}
