// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('templatetool');

#import('package:args/args.dart');
#import('dart:io');

#import('../../lib/html5parser/htmltree.dart');
#import('../lib/cmd_options.dart');
#import('../lib/file_system.dart');
#import('../lib/file_system_vm.dart');
#import('../lib/source.dart');
#import('../lib/world.dart');
#import('compile.dart');
#import('compilation_unit.dart');
#import('codegen.dart');
#import('template.dart');
#import('utils.dart');

FileSystem files;

// TODO(terry): Hacky way of finding stuff.  Our libraries should be part of
//              SDK so we can use package sdk:.
final String _DART_WEB_COMPONENTS = "/dart-web-components";
int computeParentPathToBase(String path) {
  int slashCount = 0;

  path = path.trim();
  if (path.length > 0) {
    if (path.lastIndexOf('/') == (path.length - 1)) {
      path = path.substring(0, path.length - 1);
    }

    int idx = path.indexOf(_DART_WEB_COMPONENTS);
    if (idx >= 0) {
      idx += _DART_WEB_COMPONENTS.length;
      String rest = path.substring(idx);
      int slashIdx = 0;
      while ((slashIdx = rest.indexOf('/', slashIdx)) >= 0) {
        slashIdx++;
        slashCount++;
      }
    }
  }

  return slashCount;
}

/**
 * Run from the `utils/css` directory.
 */
void main() {
  // tool.dart [options...] <sourcefile fullpath> <outputfile fullpath>
  var args = commandOptions();
  ArgResults results = args.parse(new Options().arguments);

  if (results['help']) {
    print('Usage: [options...] sourcefile [outputPath]\n');
    print(args.getUsage());
    print("   sourcefile - template file filename.html");
    print("   outputPath - if specified directory to generate files; if not");
    print("                outputPath is same directory as sourcefile path");
    return;
  }

  files = new VMFileSystem();

  // TODO(terry): Cleanup options handling need common options between template
  //              and CSS parsers also cleanup above cruft.

  // TODO(terry): Pass on switches.
  initHtmlWorld(parseOptions(results, files));

  // argument 0 - sourcefile full path
  // argument 1 - output path
  String sourceFullFn = results.rest[0];
  String outputDirectory = results.rest.length > 1 ? results.rest[1] : null;

  File fileSrc = new File(sourceFullFn);

  if (!fileSrc.existsSync()) {
    world.fatal("Source file doesn't exist - $sourceFullFn");
  }

  Directory sourcePath = fileSrc.directorySync();
  String sourceFilename = fileSrc.name;

  Path srcPath = new Path(sourceFullFn);
  // The createSync is required to ensure that the directory is fully qualified
  // using the current working directory.
  File fileIn = new File.fromPath(srcPath);
  fileIn.createSync();
  Directory srcDir = fileIn.directorySync();
  if (!srcDir.existsSync()) {
    world.fatal("Input directory doesn't exist - srcDir");
  }

  // If not outputDirectory not specified use the directory of the source file.
  if (outputDirectory == null || outputDirectory.isEmpty()) {
    outputDirectory = srcDir.path;
  }

  // The createSync is required to ensure that the directory is fully qualified
  // using the current working directory.
  Directory outDirectory = new Directory(outputDirectory);
  if (!outDirectory.existsSync()) {
    world.fatal("Output directory doesn't exist - ${outDirectory.path}");
  }

  // TODO(terry): Hacky way of finding all our libraries; should use package
  //              when we're part of the SDK.
  int numParents = computeParentPathToBase(outDirectory.path);

  if (!files.fileExists(sourceFullFn)) {
    // Display colored error message if file is missing.
    world.fatal("CSS source file missing - ${sourceFullFn}");
  } else {
    String source = files.readAll(sourceFullFn);
    try {
      final compileElapsed = time(() {
        var analyze = new Compile(files, srcDir.path, srcPath.filename,
            numParents);
        // Write out the results.
        print("Write files to ${outDirectory.path}:");

        String outDirPath = outDirectory.path;
        // Write out the code associated with each compilation unit.
        analyze.forEach((CompilationUnit cu) {
//          if (!cu.opened || !cu.codeGenerated || !cu.htmlGenerated) {
          if (!cu.opened || !cu.codeGenerated) {
            world.error(
                "Unexpected compiler error CU ${cu.filename} not processed.");
          } else {
            // Source filename associated with this compilation unit.
            String filename = cu.filename;

            // Output .dart file.
            String dartFilename = "$filename.dart";
            files.writeString("$outDirPath/$dartFilename", cu.code);
            print("  Writing $dartFilename");

            // Otuput the .html file.
//            String htmlFilename = "$filename.html";
//            files.writeString("$outDirPath/$htmlFilename", cu.html);
//            print("  Writing $htmlFilename");
          }
        });
      });

      printStats("Compiled", compileElapsed, sourceFullFn);
    } catch (final htmlException) {
      // TODO(terry): TBD
      print("ERROR unhandled EXCEPTION");
    }
  }
}
