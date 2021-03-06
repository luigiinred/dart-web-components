// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class Tokenizer extends CSSTokenizerBase {
  TokenKind cssTokens;

  bool _selectorParsing;

  Tokenizer(SourceFile source, bool skipWhitespace, [int index = 0])
    : super(source, skipWhitespace, index), _selectorParsing = false {
    cssTokens = new TokenKind();
  }

  int get startIndex() => _startIndex;

  Token next() {
    // keep track of our starting position
    _startIndex = _index;

    if (_interpStack != null && _interpStack.depth == 0) {
      var istack = _interpStack;
      _interpStack = _interpStack.pop();

      /* TODO(terry): Enable for variable and string interpolation.
       * if (istack.isMultiline) {
       *   return finishMultilineStringBody(istack.quote);
       * } else {
       *   return finishStringBody(istack.quote);
       * }
       */
    }

    int ch;
    ch = _nextChar();
    switch (ch) {
      case 0:
        return _finishToken(TokenKind.END_OF_FILE);
      case TokenChar.SPACE:
      case TokenChar.TAB:
      case TokenChar.NEWLINE:
      case TokenChar.RETURN:
        return finishWhitespace();
      case TokenChar.END_OF_FILE:
        return _finishToken(TokenKind.END_OF_FILE);
      case TokenChar.AT:
        return _finishToken(TokenKind.AT);
      case TokenChar.DOT:
        int start = _startIndex;             // Start where the dot started.
        if (maybeEatDigit()) {
          // looks like a number dot followed by digit(s).
          Token number = finishNumber();
          if (number.kind == TokenKind.INTEGER) {
            // It's a number but it's preceeded by a dot, so make it a double.
            _startIndex = start;
            return _finishToken(TokenKind.DOUBLE);
          } else {
            // Don't allow dot followed by a double (e.g,  '..1').
            return _errorToken();
          }
        } else {
          // It's really a dot.
          return _finishToken(TokenKind.DOT);
        }
      case TokenChar.LPAREN:
        return _finishToken(TokenKind.LPAREN);
      case TokenChar.RPAREN:
        return _finishToken(TokenKind.RPAREN);
      case TokenChar.LBRACE:
        return _finishToken(TokenKind.LBRACE);
      case TokenChar.RBRACE:
        return _finishToken(TokenKind.RBRACE);
      case TokenChar.LBRACK:
        return _finishToken(TokenKind.LBRACK);
      case TokenChar.RBRACK:
        return _finishToken(TokenKind.RBRACK);
      case TokenChar.HASH:
        return _finishToken(TokenKind.HASH);
      case TokenChar.PLUS:
        if (maybeEatDigit()) {
          return finishNumber();
        } else {
          return _finishToken(TokenKind.PLUS);
        }
      case TokenChar.MINUS:
        if (maybeEatDigit()) {
          return finishNumber();
        } else if (TokenizerHelpers.isIdentifierStart(ch)) {
          return this.finishIdentifier(ch);
        } else {
          return _finishToken(TokenKind.MINUS);
        }
      case TokenChar.GREATER:
        return _finishToken(TokenKind.GREATER);
      case TokenChar.TILDE:
        if (_maybeEatChar(TokenChar.EQUALS)) {
          return _finishToken(TokenKind.INCLUDES);          // ~=
        } else {
          return _finishToken(TokenKind.TILDE);
        }
      case TokenChar.ASTERISK:
        if (_maybeEatChar(TokenChar.EQUALS)) {
          return _finishToken(TokenKind.SUBSTRING_MATCH);   // *=
        } else {
          return _finishToken(TokenKind.ASTERISK);
        }
      case TokenChar.NAMESPACE:
        return _finishToken(TokenKind.NAMESPACE);
      case TokenChar.COLON:
        return _finishToken(TokenKind.COLON);
      case TokenChar.COMMA:
        return _finishToken(TokenKind.COMMA);
      case TokenChar.SEMICOLON:
        return _finishToken(TokenKind.SEMICOLON);
      case TokenChar.PERCENT:
        return _finishToken(TokenKind.PERCENT);
      case TokenChar.SINGLE_QUOTE:
        return _finishToken(TokenKind.SINGLE_QUOTE);
      case TokenChar.DOUBLE_QUOTE:
        return _finishToken(TokenKind.DOUBLE_QUOTE);
      case TokenChar.SLASH:
        if (_maybeEatChar(TokenChar.ASTERISK)) {
          return finishMultiLineComment();
        } else {
          return _finishToken(TokenKind.SLASH);
        }
      case  TokenChar.LESS:      // <!--
        if (_maybeEatChar(TokenChar.BANG) &&
            _maybeEatChar(TokenChar.MINUS) &&
            _maybeEatChar(TokenChar.MINUS)) {
          return finishMultiLineComment();
        } else {
          return _finishToken(TokenKind.LESS);
        }
      case TokenChar.EQUALS:
        return _finishToken(TokenKind.EQUALS);
      case TokenChar.OR:
        if (_maybeEatChar(TokenChar.EQUALS)) {
          return _finishToken(TokenKind.DASH_MATCH);      // |=
        } else {
          return _finishToken(TokenKind.OR);
        }
      case TokenChar.CARET:
        if (_maybeEatChar(TokenChar.EQUALS)) {
          return _finishToken(TokenKind.PREFIX_MATCH);    // ^=
        } else {
          return _finishToken(TokenKind.CARET);
        }
      case TokenChar.DOLLAR:
        if (_maybeEatChar(TokenChar.EQUALS)) {
          return _finishToken(TokenKind.SUFFIX_MATCH);    // $=
        } else {
          return _finishToken(TokenKind.DOLLAR);
        }
      case TokenChar.BANG:
        Token tok = finishIdentifier(ch);
        return (tok == null) ? _finishToken(TokenKind.BANG) : tok;
      default:
        if (TokenizerHelpers.isIdentifierStart(ch)) {
          return this.finishIdentifier(ch);
        } else if (TokenizerHelpers.isDigit(ch)) {
          return this.finishNumber();
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
    // Is the identifier a unit type?
    int tokId = TokenKind.matchUnits(_text, _startIndex, _index - _startIndex);
    if (tokId == -1) {
      // No, is it a directive?
      tokId = TokenKind.matchDirectives(
          _text, _startIndex, _index - _startIndex);
    }
    if (tokId == -1) {
      tokId = (_text.substring(_startIndex, _index) == '!important') ?
          TokenKind.IMPORTANT : -1;
    }

    return tokId >= 0 ? tokId : TokenKind.IDENTIFIER;
  }

  // Need to override so CSS version of isIdentifierPart is used.
  Token finishIdentifier(int ch) {
    while (_index < _text.length) {
//      if (!TokenizerHelpers.isIdentifierPart(_text.charCodeAt(_index++))) {
      if (!TokenizerHelpers.isIdentifierPart(_text.charCodeAt(_index))) {
//        _index--;
        break;
      } else {
        _index += 1;
      }
    }
    if (_interpStack != null && _interpStack.depth == -1) {
      _interpStack.depth = 0;
    }
    int kind = getIdentifierKind();
    if (kind == TokenKind.IDENTIFIER) {
      return _finishToken(TokenKind.IDENTIFIER);
    } else {
      return _finishToken(kind);
    }
  }

  Token finishImportant() {

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

  bool maybeEatDigit() {
    if (_index < _text.length
        && TokenizerHelpers.isDigit(_text.charCodeAt(_index))) {
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
    if (_index < _text.length
        && TokenizerHelpers.isHexDigit(_text.charCodeAt(_index))) {
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
      } else if (ch == TokenChar.MINUS) {
        /* Check if close part of Comment Definition --> (CDC). */
        if (_maybeEatChar(TokenChar.MINUS)) {
          if (_maybeEatChar(TokenChar.GREATER)) {
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
/** Static helper methods. */
class TokenizerHelpers {

  static bool isIdentifierStart(int c) {
    return ((c >= 97/*a*/ && c <= 122/*z*/) || (c >= 65/*A*/ && c <= 90/*Z*/) ||
        c == 95/*_*/ || c == 45 /*-*/);
  }

  static bool isDigit(int c) {
    return (c >= 48/*0*/ && c <= 57/*9*/);
  }

  static bool isHexDigit(int c) {
    return (isDigit(c) || (c >= 97/*a*/ && c <= 102/*f*/)
        || (c >= 65/*A*/ && c <= 70/*F*/));
  }

  static bool isIdentifierPart(int c) {
    return (isIdentifierStart(c) || isDigit(c) || c == 45 /*-*/);
  }
}

