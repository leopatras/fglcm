// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: http://codemirror.net/LICENSE

//per mode by Leo Schubert

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
"use strict";

CodeMirror.defineMode("per", function() {
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
      if (state.GRIDMAYSTART && ch !="{") {
        state.GRIDMAYSTART=false;
      }

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
        if (state.IN_GRID) {
          state.IN_GRID2=true;
          return "number";
        }
        if (state.GRIDMAYSTART) {
          state.GRIDMAYSTART=false;
          state.IN_GRID=true;
          return "builtin";
        }
        state.tokenize = tokenComment;
        return tokenComment(stream, state);
      }
      else if (state.IN_GRID && !state.IN_TAG && ch == "<") {
        state.IN_TAG=true;
        return "builtin";
      }
      else if (state.IN_GRID && state.IN_TAG && ch == ">") {
        state.IN_TAG=false;
        return "builtin";
      }
      else if (state.IN_GRID && !state.IN_BRACKET && !state.IN_TAG && ch == "[") {
        state.IN_BRACKET=true;
        return "bracket";
      }
      else if (state.IN_GRID && state.IN_BRACKET && !state.IN_TAG && ch == "|") {
        return "bracket";
      }
      else if (state.IN_GRID && state.IN_BRACKET && !state.IN_TAG && ch == "]") {
        state.IN_BRACKET=false;
        return "bracket";
      }
      else if (state.IN_GRID2 && ch == "}") {
        state.IN_GRID2=false;
        return "number";
      }
      else if (state.IN_GRID && ch == "}") {
        state.IN_GRID=false;
        state.IN_TAG=false;
        state.IN_BRACKET=false;
        return "builtin";
      }
      else if (ch == "-") {
        if (stream.eat("-")) {
          stream.skipToEnd();
          return "comment";
        }
      }
      else if (!state.IN_GRID && (ch == "," || ch=="." || ch=="=" ||ch==":" )) {
        return "qualifier";
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
        if (keywords && keywords.propertyIsEnumerable(word)) {
          if (state.IN_GRID) {
            if (state.IN_TAG && word=="GROUP" || word=="SCROLLGRID" || word=="TABLE") {
              return "keyword";
            }
            return "meta";
          } else {
            if (word=="GRID"||word=="SCREEN"||word=="TABLE"||word=="SCROLLGRID") {
              state.GRIDMAYSTART=true;
            }
          } 
          return "keyword";
        } else if (state.IN_GRID && state.IN_TAG) {
          if (word=="G" || word=="S" || word=="T") { //GST :-)
            return "keyword";
          }
        }
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
CodeMirror.defineMIME("text/x-per", "per");

});
