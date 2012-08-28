// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('processor');

#import('dart:coreimpl');
#import('../../lib/html5parser/htmltree.dart');
#import('../lib/world.dart');
#import('../lib/file_system.dart');
#import('compile.dart');
#import('compilation_unit.dart');
#import('template.dart');
#import('utils.dart');

/**
 * Class used to store the Compilation unit, the basic unit the compiler
 * associates with each file.  This unit is used for each phase of the compiler.
 *
 * The current phases (in order) are PARSING, WALKING the HTML tree, ANALYZING
 * all files, and EMITTING Dart code and the HTML files.  Each phase progress
 * throw a process' state PROCESS_WAITING, PROCESS_RUNNING or PROCESS_DONE.
 *
 * A process waiting signals a particular phase (the current phase) is waiting
 * to run at some future time.  Only one process can run (single threaded).
 *
 * When a process is done the process transitions to it's next phase with a
 * process state of WAITING.
 *
 * When all processes phases are COMPLETE and each process state is DONE then
 * the NULL_PROCESS is returned signaling no more processes to run.
 */
class ProcessFile {
  static ProcessFile _nullProcess;

  /** Basic compiler unit; file being compiled. */
  final CompilationUnit _compilationUnit;

  /** All phases of the template compiler in order or execution. */
  static const int PARSING = 1;         // Parse the document.
  static const int WALKING = 2;         // Walk the HTML tree.
  static const int ANALYZING = 3;       // Global analysis.
  static const int EMITTING = 4;        // Emitting the code.
  static const int COMPLETE = 5;        // All phases complete.

  /** Current phase of the compiler (see above states). */
  int _phase;

  /** All states of a process. */
  static const int PROCESS_WAITING = 1;         // Waiting to run.
  static const int PROCESS_RUNNING = 2;         // Running.
  static const int PROCESS_DONE = 3;            // Process complete.

  /** States of a process for the current phase of the file being compiled. */
  int _processState;

  /** Queue up other files to process (e.g., web components). */
  ProcessFile(CompilationUnit unit)
      : _compilationUnit = unit,
        _phase = PARSING,
        _processState = PROCESS_WAITING;

  ProcessFile._nullProcess() : _compilationUnit = null;

  /** The null process is returned when all processes phases are complete. */
  static ProcessFile get NULL_PROCESS() {
    if (_nullProcess == null) {
      _nullProcess = new ProcessFile._nullProcess();
    }
    return _nullProcess;
  }

  /** Compiler's order of transitioning from one compiler phase to another. */
  void transition() {
    Expect.isTrue(isProcessDone);

    switch (phase) {
      case ProcessFile.PARSING:
        _phase = WALKING;
        _processState = PROCESS_WAITING;
        break;
      case ProcessFile.WALKING:
        _processState = PROCESS_WAITING;
        _phase = ANALYZING;
        break;
      case ProcessFile.ANALYZING:
        _processState = PROCESS_WAITING;
        _phase = EMITTING;
        break;
      case ProcessFile.EMITTING:
        _processState = PROCESS_DONE;
        _phase = COMPLETE;
        break;
      case ProcessFile.COMPLETE:
        break;
    }
  }

  int get phase() => _phase;
  int get processState() => _processState;

  /** Phases of the compiler. */
  bool get isParsing() => _phase == PARSING;
  bool get isWalking() => _phase == WALKING;
  bool get isAnalyzing() => _phase == ANALYZING;
  bool get isEmitting() => _phase == EMITTING;
  bool get isComplete() => _phase == COMPLETE;

  /** Process state of a compiler's phase. */
  bool get isProcessWaiting() => _processState == PROCESS_WAITING;
  bool get isProcessRunning() => _processState == PROCESS_RUNNING;
  bool get isProcessDone() => _processState == PROCESS_DONE;

  bool get isLowest() => isParsing && isProcessWaiting;

  void toProcessWaiting() {
    _processState = PROCESS_WAITING;
  }

  void toProcessRunning() {
    _processState = PROCESS_RUNNING;
  }

  void toProcessDone() {
    _processState = PROCESS_DONE;
  }

  CompilationUnit get cu() => _compilationUnit;

  String toString() =>
      "Phase: $_phase, State: $_processState, CU: $_compilationUnit";
}

// TODO(terry): Someday asynchronously process all files emitting specific code
//              for each component.  When all files are processed then the
//              global analysis could then be done for the main code to be
//              emitted.  Today all files are processed serially in each phase.
/**
 * All files associated with this compile.  Manages all phases
 * of compilation (parsing, analysis, and the emitting of code).
 */
class ProcessFiles {
  final List<ProcessFile> _files;

  /**
   * Used on the initial file.  [filename] is the starting file alreadying
   *  parsed, [doc] is the doc to process.
   */
  ProcessFiles() : _files = [];

  /** Another compiler file dependency. */
  void add(String filename,
           [int fileType = CompilationUnit.TYPE_COMPONENT]) {
    CompilationUnit cu =
        new CompilationUnit(filename, new ElemCG(this), fileType);
    _files.add(new ProcessFile(cu));
  }

  /**
   * This is the heart of the processor.  The job of nextProcess is to mark the
   * phase of the process that is done (but not in the COMPLETED phase).
   * Transition that process to the next phase with a process state of WAITING.
   *
   * Then return the next process to run.  The ordering is by phases (phase 1
   * PARSING, runs before phase 2 WALKING, etc.) whose process state is WAITING.
   *
   * When all processes are in phase COMPLETE with a process state of DONE; then
   * the NULL_PROCESS is returned signalling all files have been parsed, walked,
   * analyzed, and code has been emited.
   */
  nextProcess() {
    ProcessFile currProcess = current;

    // Something is still running?
    if (currProcess == null) {
      // Nothing is running; find the next process to run.
      ProcessFile lowestProcess;
      for (ProcessFile process in _files) {
        if (process.isProcessDone) {
          // If the process is done; then transition that process to the next
          // phase.
          process.transition();
        }

        // Find the next lowest process to return to start running.
        if (lowestProcess == null) {
          lowestProcess = process;
        } else {
          if (process.phase < lowestProcess.phase) {
            // Return the lowest phase.
            lowestProcess = process;
          } else if (process.phase == lowestProcess.phase) {
            // Process phase is equal the lowest process we've seen; then check
            // if this processState is lower if so it's our new lowestProcess.
            if (process.processState < lowestProcess.processState) {
              lowestProcess = process;
            }
          }
        }

        // Shortcircuit once we have a lowest process that's the one.
        if (lowestProcess.isLowest) {
          return lowestProcess;
        }
      }

      Expect.isNotNull(lowestProcess);

      // If our lowestProcess isn't done then run this process.
      if (!lowestProcess.isProcessDone) {
        return lowestProcess;
      } else {
        // Nothing more to do; The NULL_PROCESS is our signal that we're done
        // doing any work.
        return ProcessFile.NULL_PROCESS;
      }
    } else {
      // Something is still running; return that process.
      return currProcess;
    }
  }

  /**
   * Return current running process; if no currently running process then null
   * is returned.
   */
  ProcessFile get current() {
    for (ProcessFile processFile in _files) {
      if (processFile.isProcessRunning) {
        return processFile;
      }
    }

    return null;
  }

  void forEach(void f(ProcessFile processFile) ) {
    for (ProcessFile pFile in _files) {
      f(pFile);
    }
  }
}
