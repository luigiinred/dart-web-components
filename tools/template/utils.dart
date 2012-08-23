// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('template_utils');

/**
 * Convert any string name with hyphens; remove hyphen and make next character
 * an upper-case letter.
 */
String toCamelCase(String knownName) {
  var dartName = new StringBuffer();
  List<String> splits = knownName.split('-');
  if (splits.length > 0) {
    dartName.add(splits[0]);
    for (int idx = 1; idx < splits.length; idx++) {
      String part = splits[idx];
      // Character between 'a'..'z' mapped to 'A'..'Z'
      dartName.add("${part[0].toUpperCase()}${part.substring(1)}");
    }
  }
}

/** Invokes [callback] and returns how long it took to execute in ms. */
num time(callback()) {
  final watch = new Stopwatch();
  watch.start();
  callback();
  watch.stop();
  return watch.elapsedInMs();
}

String GREEN_COLOR = '\u001b[32m';
String NO_COLOR = '\u001b[0m';

prettyStats(String phase, num elapsed, [String filename = '']) {
  print('$phase $GREEN_COLOR$filename$NO_COLOR in $elapsed msec.');
}

printStats(String phase, num elapsed, [String filename = '']) {
  print('$phase $filename in $elapsed msec.');
}
