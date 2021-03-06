// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('tools');

#import('package:args/args.dart');
#import('world.dart');

/** Extracts options from command-line arguments. */
CmdOptions parseOptions(ArgResults args, var files) {
  assert(options == null);
  return new CmdOptions(args, files);
}

class CmdOptions {
  // TODO(terry): Do we ever want to support throw on fatal?
  bool throwOnFatal = false;
  bool warningsAsErrors;

  // Message support
  bool throwOnErrors;
  bool throwOnWarnings;
  bool showInfo;
  bool showWarnings;
  bool useColors;

  CmdOptions(ArgResults args, var files) {
    warningsAsErrors = args['warnings_as_errors'];
    throwOnErrors = args['throw_on_errors'];
    throwOnWarnings = args['throw_on_warnings'];
    showInfo = args['verbose'];
    showWarnings = args['suppress_warnings'];
    useColors = args['no_colors'];
  }
}
