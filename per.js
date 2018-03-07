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
var keywords={
"ACCELERATOR":true
,"ACCELERATOR2":true
,"ACCELERATOR3":true
,"ACCELERATOR4":true
,"ACTION":true
,"ACTIONIMAGE":true
,"ACTIONTEXT":true
,"AGGREGATE":true
,"AGGREGATETEXT":true
,"AGGREGATETYPE":true
,"ALT":true
,"AND":true
,"ATTRIBUTES":true
,"AUTO":true
,"AUTONEXT":true
,"AUTOSCALE":true
,"AVG":true
,"BETWEEN":true
,"BIGINT":true
,"BLACK":true
,"BLINK":true
,"BLUE":true
,"BOOLEAN":true
,"BOTH":true
,"BUTTON":true
,"BUTTONEDIT":true
,"BUTTONTEXTHIDDEN":true
,"BY":true
,"BYTE":true
,"CANVAS":true
,"CENTER":true
,"CENTURY":true
,"CHAR":true
,"CHARACTER":true
,"CHARACTERS":true
,"CHECKBOX":true
,"CLASS":true
,"COLOR":true
,"COLUMNS":true
,"COMBOBOX":true
,"COMMAND":true
,"COMMENT":true
,"COMMENTS":true
,"COMPACT":true
,"COMPLETER":true
,"COMPONENTTYPE":true
,"COMPRESS":true
,"CONFIG":true
,"CONTEXTMENU":true
,"CONTROL":true
,"COUNT":true
,"CURRENT":true
,"CYAN":true
,"DATABASE":true
,"DATE":true
,"DATEEDIT":true
,"DATETIME":true
,"DATETIMEEDIT":true
,"DAY":true
,"DEC":true
,"DECIMAL":true
,"DEFAULT":true
,"DEFAULTS":true
,"DEFAULTVIEW":true
,"DELIMITERS":true
,"DISCLOSUREINDICATOR":true
,"DISPLAY":true
,"DISPLAYONLY":true
,"DOUBLE":true
,"DOUBLECLICK":true
,"DOWNSHIFT":true
,"DYNAMIC":true
,"EDIT":true
,"EMAIL":true
,"END":true
,"EXPANDEDCOLUMN":true
,"FALSE":true
,"FIELD":true
,"FIXED":true
,"FLOAT":true
,"FOLDER":true
,"FONTPITCH":true
,"FORM":true
,"FORMAT":true
,"FORMONLY":true
,"FRACTION":true
,"GREEN":true
,"GRID":true
,"GRIDCHILDRENINPARENT":true
,"GROUP":true
,"HBOX":true
,"HEIGHT":true
,"HIDDEN":true
,"HORIZONTAL":true
,"HOUR":true
,"IDCOLUMN":true
,"IMAGE":true
,"IMAGECOLLAPSED":true
,"IMAGECOLUMN":true
,"IMAGEEXPANDED":true
,"IMAGELEAF":true
,"INCLUDE":true
,"INITIAL":true
,"INITIALIZER":true
,"INITIALPAGESIZE":true
,"INPUT":true
,"INSTRUCTIONS":true
,"INT":true
,"INTEGER":true
,"INTERVAL":true
,"INVISIBLE":true
,"IS":true
,"ISNODECOLUMN":true
,"ITEM":true
,"ITEMS":true
,"JUSTIFY":true
,"KEY":true
,"KEYBOARDHINT":true
,"KEYS":true
,"LABEL":true
,"LAYOUT":true
,"LEFT":true
,"LIKE":true
,"LINES":true
,"MAGENTA":true
,"MATCHES":true
,"MAX":true
,"MIN":true
,"MINHEIGHT":true
,"MINUTE":true
,"MINWIDTH":true
,"MONEY":true
,"MONTH":true
,"NO":true
,"NOENTRY":true
,"NONCOMPRESS":true
,"NONE":true
,"NORMAL":true
,"NOT":true
,"NOTEDITABLE":true
,"NOUPDATE":true
,"NULL":true
,"NUMBER":true
,"NUMERIC":true
,"OPTIONS":true
,"OR":true
,"ORIENTATION":true
,"PACKED":true
,"PAGE":true
,"PARENTIDCOLUMN":true
,"PHANTOM":true
,"PHONE":true
,"PICTURE":true
,"PIXELHEIGHT":true
,"PIXELS":true
,"PIXELWIDTH":true
,"PLACEHOLDER":true
,"POINTS":true
,"PRECISION":true
,"PROGRAM":true
,"PROGRESSBAR":true
,"PROPERTIES":true
,"QUERYCLEAR":true
,"QUERYEDITABLE":true
,"RADIOGROUP":true
,"REAL":true
,"RECORD":true
,"RED":true
,"REQUIRED":true
,"REVERSE":true
,"RIGHT":true
,"SAMPLE":true
,"SCHEMA":true
,"SCREEN":true
,"SCROLL":true
,"SCROLLBARS":true
,"SCROLLGRID":true
,"SECOND":true
,"SEPARATOR":true
,"SHIFT":true
,"SIZE":true
,"SIZEPOLICY":true
,"SLIDER":true
,"SMALLFLOAT":true
,"SMALLINT":true
,"SPACING":true
,"SPINEDIT":true
,"SPLITTER":true
,"STACK":true
,"STEP":true
,"STRETCH":true
,"STYLE":true
,"SUM":true
,"TABINDEX":true
,"TABLE":true
,"TABLES":true
,"TAG":true
,"TEXT":true
,"TEXTEDIT":true
,"THROUGH":true
,"THRU":true
,"TIMEEDIT":true
,"TIMESTAMP":true
,"TITLE":true
,"TO":true
,"TODAY":true
,"TOOLBAR":true
,"TOPMENU":true
,"TREE":true
,"TRUE":true
,"TYPE":true
,"UNDERLINE":true
,"UNHIDABLE":true
,"UNHIDABLECOLUMNS":true
,"UNMOVABLE":true
,"UNMOVABLECOLUMNS":true
,"UNSIZABLE":true
,"UNSIZABLECOLUMNS":true
,"UNSORTABLE":true
,"UNSORTABLECOLUMNS":true
,"UPSHIFT":true
,"USER":true
,"VALIDATE":true
,"VALUECHECKED":true
,"VALUEMAX":true
,"VALUEMIN":true
,"VALUEUNCHECKED":true
,"VARCHAR":true
,"VARIABLE":true
,"VBOX":true
,"VERIFY":true
,"VERSION":true
,"VERTICAL":true
,"WANTFIXEDPAGESIZE":true
,"WANTNORETURNS":true
,"WANTTABS":true
,"WEBCOMPONENT":true
,"WHERE":true
,"WHITE":true
,"WIDGET":true
,"WIDTH":true
,"WINDOWSTYLE":true
,"WITHOUT":true
,"WORDWRAP":true
,"X":true
,"XEDIT":true
,"Y":true
,"YEAR":true
,"YELLOW":true
,"YES":true
,"ZEROFILL":true
}//keywords

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
      else if (ch == "," || ch=="." || ch=="=" ) {
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
