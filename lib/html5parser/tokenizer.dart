// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('tokenizer');

#import('../../tools/lib/source.dart');
#import('../../tools/lib/world.dart');

#import('tokenkind.dart');

#source('token.dart');
#source('tokenizer_base.dart');

class Tokenizer extends TokenizerBase {
  TokenKind tmplTokens;

  bool _selectorParsing;

  Tokenizer(SourceFile source, bool skipWhitespace, [int index = 0])
    : super(source, skipWhitespace, index), _selectorParsing = false {
      tmplTokens = new TokenKind();
  }

  int get startIndex() => _startIndex;
  void set index(int idx) {
    _index = idx;
  }

  Token next([bool inTag = true]) {
    // keep track of our starting position
    _startIndex = _index;

    int ch;
    ch = _nextChar();
    switch(ch) {
      case 0:
        return _finishToken(TokenKind.END_OF_FILE);
      case TokenChar.SPACE:
      case TokenChar.TAB:
      case TokenChar.NEWLINE:
      case TokenChar.RETURN:
        if (inTag) {
          return finishWhitespace();
        } else {
          return _finishToken(TokenKind.WHITESPACE);
        }
      case TokenChar.END_OF_FILE:
        return _finishToken(TokenKind.END_OF_FILE);
      case TokenChar.LESS_THAN:
        if (_peekChar() == TokenChar.EXCLAMATION &&
            _peekChar(1) == TokenChar.MINUS &&
            _peekChar(2) == TokenChar.MINUS) {
          if (_maybeEatChar(TokenChar.EXCLAMATION) &&
              _maybeEatChar(TokenChar.MINUS) &&
              _maybeEatChar(TokenChar.MINUS)) {
            return finishCDATA();
          }
        }
        return _finishToken(TokenKind.LESS_THAN);
      case TokenChar.GREATER_THAN:
        return _finishToken(TokenKind.GREATER_THAN);
      case TokenChar.EQUAL:
        if (inTag) {
          int singleQuote = TokenChar.SINGLE_QUOTE;
          int doubleQuote = TokenChar.DOUBLE_QUOTE;
          if (_maybeEatChar(singleQuote)) {
            return finishQuotedAttrValue(singleQuote);
          } else if (_maybeEatChar(doubleQuote)) {
            return finishQuotedAttrValue(doubleQuote);
          } else if (TokenizerHelpers.isAttributeValueStart(_peekChar())) {
            return finishAttrValue();
          }
        }
        return _finishToken(TokenKind.EQUAL);
      case TokenChar.SLASH:
        if (_maybeEatChar(TokenChar.GREATER_THAN)) {
          return _finishToken(TokenKind.END_NO_SCOPE_TAG);        // />
        } else if (_maybeEatChar(TokenChar.ASTERISK)) {
          return finishMultiLineComment();
        } else {
          return _finishToken(TokenKind.SLASH);
        }
      case TokenChar.LBRACE:
        if (_maybeEatChar(TokenChar.LBRACE)) {
          return finishExpression();
        } else {
          return _finishToken(TokenKind.LBRACE);
        }
      case TokenChar.RBRACE:
        return _finishToken(TokenKind.RBRACE);
      case TokenChar.EXCLAMATION:
        if (inTag) {
          return this.finishIdentifier();
        }
        return _finishToken(TokenKind.EXCLAMATION);
      default:
        if (TokenizerHelpers.isIdentifierStart(ch)) {
          return this.finishIdentifier();
        } else if (TokenizerHelpers.isDigit(ch)) {
          return this.finishNumber();
        } else if (inTag) {
          // Text node.... keep reading as a string.
        } else {
          return _errorToken();
        }
    }
  }

  // TODO(jmesserly): we need a way to emit human readable error messages from
  // the tokenizer.
  Token _errorToken([String message = null]) {
    return _finishToken(TokenKind.ERROR);
  }

  int getIdentifierKind() {
    // Is the identifier an element?
    int tokId = TokenKind.matchElements(_text, _startIndex,
      _index - _startIndex);

    return tokId >= 0 ? tokId : TokenKind.IDENTIFIER;
  }

  // Need to override so CSS version of isIdentifierPart is used.
  Token finishIdentifier() {
    while (_index < _text.length) {
      if (!TokenizerHelpers.isIdentifierPart(_text.charCodeAt(_index))) {
        break;
      } else {
        _index += 1;
      }
    }
    return _finishToken(getIdentifierKind());
  }

  Token _makeAttributeValueToken(List<int> buf) {
    final s = new String.fromCharCodes(buf);
    return new LiteralToken(TokenKind.ATTR_VALUE, _source, _startIndex, _index,
      s);
  }

  Token _makeExpressionToken(List<int> buf) {
    final s = new String.fromCharCodes(buf);
    return new LiteralToken(TokenKind.EXPRESSION, _source, _startIndex, _index,
      s.trim());
  }

  /* quote if -1 signals to read upto first whitespace otherwise read upto
   * single or double quote char.
   */
  Token xfinishQuotedAttrValue([int quote = -1]) {
    var buf = new List<int>();
    while (true) {
      int ch = _nextChar();
      if (ch == quote) {
        return _makeAttributeValueToken(buf);
      } else if (ch == 0) {
        return _errorToken();
      } else {
        buf.add(ch);
      }
    }
  }

  Token finishAttrValue() {
    var buf = new List<int>();
    while (true) {
      int ch = _peekChar();
      if (TokenizerHelpers.isWhitespace(ch) || TokenizerHelpers.isSlash(ch) ||
          TokenizerHelpers.isCloseTag(ch)) {
        return _makeAttributeValueToken(buf);
      } else if (ch == 0) {
        return _errorToken();
      } else {
        buf.add(_nextChar());
      }
    }
  }

  Token finishQuotedAttrValue([int quote = -1]) {
    var buf = new List<int>();

    if (maybeEatStartExpression()) {
      return finishExpression(quote);
    } else {
      while (true) {
        int ch = _nextChar();
        if (ch == quote) {
          return _makeAttributeValueToken(buf);
        } else if (ch == 0) {
          return _errorToken();
        } else {
          buf.add(ch);
        }
      }
    }
  }

  /* quote if -1 signals to read upto first whitespace otherwise read upto
   * single or double quote char.
   */
  Token finishExpression([int quote = -1]) {
    int start = _index;
    var buf = new List<int>();
    while (true) {
      if (maybeEatEndExpression()) {
        // Get the expression
        if (quote != -1) {
          while (true) {
            int ch = _nextChar();
            if (ch == quote) {
              break;
            } else if (ch == 0) {
              return _errorToken();
            }
          }
        }

        return _makeExpressionToken(buf);
      }
      int ch = _nextChar();
      if (ch == 0) {
        return _errorToken();
      } else {
        buf.add(ch);
      }
    }
  }

  Token finishNumber() {
    eatDigits();

    if (_peekChar() == 46/*.*/) {
      // Handle the case of 1.toString().
      _nextChar();
      if (TokenizerHelpers.isDigit(_peekChar())) {
        eatDigits();
        return _finishToken(TokenKind.DOUBLE);
      } else {
        _index -= 1;
      }
    }

    return _finishToken(TokenKind.INTEGER);
  }

  bool maybeEatStartExpression() {
    if (_index + 1 < _text.length &&
        TokenizerHelpers.isLBrace(_text.charCodeAt(_index)) &&
        TokenizerHelpers.isLBrace(_text.charCodeAt(_index + 1))) {
      _index += 2;
      return true;
    }
    return false;
  }

  bool maybeEatEndExpression() {
    if (_index + 1 < _text.length &&
        TokenizerHelpers.isRBrace(_text.charCodeAt(_index)) &&
        TokenizerHelpers.isRBrace(_text.charCodeAt(_index + 1))) {
      _index += 2;
      return true;
    }
    return false;
  }

  bool maybeEatDigit() {
    if (_index < _text.length && TokenizerHelpers.isDigit(
        _text.charCodeAt(_index))) {
      _index += 1;
      return true;
    }
    return false;
  }

  void eatHexDigits() {
    while (_index < _text.length) {
     if (TokenizerHelpers.isHexDigit(_text.charCodeAt(_index))) {
       _index += 1;
     } else {
       return;
     }
    }
  }

  bool maybeEatHexDigit() {
    if (_index < _text.length && TokenizerHelpers.isHexDigit(
        _text.charCodeAt(_index))) {
      _index += 1;
      return true;
    }
    return false;
  }

  Token finishMultiLineComment() {
    while (true) {
      int ch = _nextChar();
      if (ch == 0) {
        return _finishToken(TokenKind.INCOMPLETE_COMMENT);
      } else if (ch == 42/*'*'*/) {
        if (_maybeEatChar(47/*'/'*/)) {
          if (_skipWhitespace) {
            return next();
          } else {
            return _finishToken(TokenKind.COMMENT);
          }
        }
      }
    }
    return _errorToken();
  }

  Token finishCDATA() {
    while (true) {
      int ch = _nextChar();
      if (ch == 0) {
        return _finishToken(TokenKind.INCOMPLETE_COMMENT);
      } else if (ch == TokenChar.MINUS) {
        /* Check if close part of Comment Definition --> (CDC). */
        if (_maybeEatChar(TokenChar.MINUS)) {
          if (_maybeEatChar(TokenChar.GREATER_THAN)) {
            if (_skipWhitespace) {
              return next();
            } else {
              return _finishToken(TokenKind.HTML_COMMENT);
            }
          }
        }
      }
    }
    return _errorToken();
  }
}


/** Static helper methods. */
class TokenizerHelpers {
  static bool isIdentifierStart(int c) {
    return ((c >= 97/*a*/ && c <= 122/*z*/) ||
        (c >= 65/*A*/ && c <= 90/*Z*/) || c == 95/*_*/);
  }

  static bool isDigit(int c) {
    return (c >= 48/*0*/ && c <= 57/*9*/);
  }

  static bool isHexDigit(int c) {
    return (isDigit(c) || (c >= 97/*a*/ && c <= 102/*f*/) ||
        (c >= 65/*A*/ && c <= 70/*F*/));
  }

  static bool isWhitespace(int c) {
    return (c == 32/*' '*/ || c == 9/*'\t'*/ || c == 10/*'\n'*/ ||
        c == 13/*'\r'*/);
  }

  static bool isIdentifierPart(int c) {
    return (isIdentifierStart(c) || isDigit(c) || c == 45/*-*/ ||
        c == 58/*:*/ || c == 46/*.*/);
  }

  static bool isInterpIdentifierPart(int c) {
    return (isIdentifierStart(c) || isDigit(c));
  }

  static bool isAttributeValueStart(int c) {
    return !isWhitespace(c) && !isSlash(c) && !isCloseTag(c);
  }

  static bool isSlash(int c) {
    return (c == 47/* / */);
  }

  static bool isCloseTag(int c) {
    return (c == 62/* > */);
  }

  static bool isLBrace(int c) {
    return (c == 123 /* { */);
  }

  static bool isRBrace(int c) {
    return (c == 125 /* } */);
  }
}

