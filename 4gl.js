// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: http://codemirror.net/LICENSE

//4gl mode by Leo Schubert

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
"use strict";

CodeMirror.defineMode("4gl", function() {
var keywords={};//TEMPLATE line which is replaced with the actual keywords

    var isOperatorChar = /[+\-*&%=<>!?^\/\|]/;
    function chain(stream, state, f) {
      state.tokenize = f;
      return f(stream, state);
    }
    function tokenBaseInt(stream, state) {
      var beforeParams = state.beforeParams;
      state.beforeParams = false;
      var ch = stream.next();
      //console.log("ch:'"+ch+"'");

      if ((ch == '"' || ch == "'")) {
        return chain(stream, state, tokenString(ch));
      }
      /*
      if (ch == '"' || ch == "'") {
        state.tokenize = tokenString(ch);
        return state.tokenize(stream, state);
      }*/
      else if (/[\(\)]/.test(ch)) {
        if (ch == "(" && beforeParams) state.inParams = true;
        else if (ch == ")") state.inParams = false;
          return null;
      }
      else if (/\d/.test(ch)) {
        stream.eatWhile(/[\w\.]/);
        return "number";
      }
      else if (ch == "#") {
        stream.skipToEnd();
        return "comment";
      }
      else if (ch == "{") {
        state.tokenize = tokenComment;
        return tokenComment(stream, state);
      }
      else if (ch == "-") {
        if (stream.eat("-")) {
          stream.skipToEnd();
          return "comment";
        }
      }
      else if (ch == '"' && stream.skipTo('"')) {
        return "string";
      }
      /*
      else if (isOperatorChar.test(ch)) {
        stream.eatWhile(isOperatorChar);
        return "comment";
      }*/
      else {
        stream.eatWhile(/[\w\$_{}\xa1-\uffff]/);
        var word = stream.current();
        if (keywords && keywords.propertyIsEnumerable(word))
          return "keyword";
        return null;
      }
    }
    function tokenBase(stream, state) {
      var ret=tokenBaseInt(stream,state);
      //console.log("  returned:"+ret);
      return ret;
    }
    function tokenString(quote) {
      return function(stream, state) {
      var escaped = false, next, end = false;
      while ((next = stream.next()) != null) {
        if (next == quote && !escaped) {
          end = true;
          break;
        }
        escaped = !escaped && next == "\\";
      }
      if (end) state.tokenize = tokenBase;
        return "string";
      };
    }
    function tokenComment(stream, state) {
      var ch;
      while (ch = stream.next()) {
        if (ch == "}") {
          state.tokenize = tokenBase;
          break;
        }
      }
      return "comment";
    }
    function tokenUnparsed(stream, state) {
      var maybeEnd = 0, ch;
      while (ch = stream.next()) {
        if (ch == "#" && maybeEnd == 2) {
          state.tokenize = tokenBase;
          break;
        }
        if (ch == "]")
          maybeEnd++;
        else if (ch != " ")
          maybeEnd = 0;
      }
      return "meta";
    }
    return {
      startState: function() {
        return {
          tokenize: tokenBase,
          beforeParams: false,
          inParams: false
        };
      },
      token: function(stream, state) {
        if (stream.eatSpace()) return null;
        return state.tokenize(stream, state);
      }
    };
});
CodeMirror.defineMIME("text/x-4gl", "4gl");

});
