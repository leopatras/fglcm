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
var keywords={
"ABSOLUTE":true
,"ACCELERATOR":true
,"ACCEPT":true
,"ACCESSORYTYPE":true
,"ACTION":true
,"ACTIONS":true
,"ADD":true
,"AFTER":true
,"ALL":true
,"ALTER":true
,"AND":true
,"ANSI":true
,"ANY":true
,"APPEND":true
,"APPLICATION":true
,"ARRAY":true
,"AS":true
,"ASC":true
,"ASCENDING":true
,"ASCII":true
,"AT":true
,"ATTRIBUTE":true
,"ATTRIBUTES":true
,"AUDIT":true
,"AUTO":true
,"AVG":true
,"BEFORE":true
,"BEGIN":true
,"BETWEEN":true
,"BIGINT":true
,"BIGSERIAL":true
,"BLACK":true
,"BLINK":true
,"BLUE":true
,"BOLD":true
,"BOOLEAN":true
,"BORDER":true
,"BOTTOM":true
,"BREAKPOINT":true
,"BUFFER":true
,"BUFFERED":true
,"BY":true
,"BYTE":true
,"CACHE":true
,"CALL":true
,"CANCEL":true
,"CASCADE":true
,"CASE":true
,"CAST":true
,"CATCH":true
,"CENTURY":true
,"CHANGE":true
,"CHAR":true
,"CHARACTER":true
,"CHECK":true
,"CHECKMARK":true
,"CIRCUIT":true
,"CLEAR":true
,"CLIPPED":true
,"CLOSE":true
,"CLUSTER":true
,"COLLAPSE":true
,"COLUMN":true
,"COLUMNS":true
,"COMMAND":true
,"COMMENT":true
,"COMMIT":true
,"COMMITTED":true
,"CONCURRENT":true
,"CONNECT":true
,"CONNECTION":true
,"CONSTANT":true
,"CONSTRAINED":true
,"CONSTRAINT":true
,"CONSTRUCT":true
,"CONTEXTMENU":true
,"CONTINUE":true
,"CONTROL":true
,"COUNT":true
,"CREATE":true
,"CROSS":true
,"CURRENT":true
,"CURSOR":true
,"CYAN":true
,"CYCLE":true
,"DATABASE":true
,"DATE":true
,"DATETIME":true
,"DAY":true
,"DBA":true
,"DBSERVERNAME":true
,"DEC":true
,"DECIMAL":true
,"DECLARE":true
,"DEFAULT":true
,"DEFAULTS":true
,"DEFAULTVIEW":true
,"DEFER":true
,"DEFINE":true
,"DELETE":true
,"DELIMITER":true
,"DESC":true
,"DESCENDING":true
,"DESCRIBE":true
,"DESTINATION":true
,"DETAILACTION":true
,"DETAILBUTTON":true
,"DIALOG":true
,"DIM":true
,"DIMENSION":true
,"DIRTY":true
,"DISCLOSUREINDICATOR":true
,"DISCONNECT":true
,"DISPLAY":true
,"DISTINCT":true
,"DORMANT":true
,"DOUBLE":true
,"DOUBLECLICK":true
,"DOWN":true
,"DRAG_ENTER":true
,"DRAG_FINISHED":true
,"DRAG_OVER":true
,"DRAG_START":true
,"DROP":true
,"DYNAMIC":true
,"ELSE":true
,"END":true
,"ERROR":true
,"ESCAPE":true
,"EVERY":true
,"EXCLUSIVE":true
,"EXECUTE":true
,"EXISTS":true
,"EXIT":true
,"EXPAND":true
,"EXPLAIN":true
,"EXTEND":true
,"EXTENT":true
,"EXTERNAL":true
,"FALSE":true
,"FETCH":true
,"FGL":true
,"FGL_DRAWBOX":true
,"FIELD":true
,"FIELD_TOUCHED":true
,"FILE":true
,"FILL":true
,"FINISH":true
,"FIRST":true
,"FLOAT":true
,"FLUSH":true
,"FOR":true
,"FOREACH":true
,"FOREIGN":true
,"FORM":true
,"FORMAT":true
,"FOUND":true
,"FRACTION":true
,"FREE":true
,"FROM":true
,"FULL":true
,"FUNCTION":true
,"GET_FLDBUF":true
,"GLOBALS":true
,"GO":true
,"GOTO":true
,"GRANT":true
,"GREEN":true
,"GROUP":true
,"HANDLER":true
,"HAVING":true
,"HEADER":true
,"HELP":true
,"HIDE":true
,"HOLD":true
,"HOUR":true
,"IDLE":true
,"IF":true
,"IIF":true
,"IMAGE":true
,"IMMEDIATE":true
,"IMPORT":true
,"IN":true
,"INCREMENT":true
,"INDEX":true
,"INFIELD":true
,"INITIALIZE":true
,"INNER":true
,"INOUT":true
,"INPUT":true
,"INSERT":true
,"INSTANCEOF":true
,"INT":true
,"INT8":true
,"INTEGER":true
,"INTERRUPT":true
,"INTERVAL":true
,"INTO":true
,"INVISIBLE":true
,"IS":true
,"ISOLATION":true
,"JAVA":true
,"JOIN":true
,"KEEP":true
,"KEY":true
,"LABEL":true
,"LAST":true
,"LEFT":true
,"LENGTH":true
,"LET":true
,"LIKE":true
,"LIMIT":true
,"LINE":true
,"LINENO":true
,"LINES":true
,"LOAD":true
,"LOCATE":true
,"LOCK":true
,"LOCKS":true
,"LOG":true
,"LSTR":true
,"LVARCHAR":true
,"MAGENTA":true
,"MAIN":true
,"MARGIN":true
,"MATCHES":true
,"MAX":true
,"MAXCOUNT":true
,"MAXVALUE":true
,"MDY":true
,"MEMORY":true
,"MENU":true
,"MESSAGE":true
,"MIDDLE":true
,"MIN":true
,"MINUTE":true
,"MINVALUE":true
,"MOD":true
,"MODE":true
,"MODIFY":true
,"MONEY":true
,"MONTH":true
,"NAME":true
,"NATURAL":true
,"NAVIGATOR":true
,"NCHAR":true
,"NEED":true
,"NEXT":true
,"NO":true
,"NOCACHE":true
,"NOCYCLE":true
,"NOMAXVALUE":true
,"NOMINVALUE":true
,"NOORDER":true
,"NORMAL":true
,"NOT":true
,"NOTFOUND":true
,"NULL":true
,"NUMERIC":true
,"NVARCHAR":true
,"NVL":true
,"OF":true
,"OFF":true
,"ON":true
,"OPEN":true
,"OPTION":true
,"OPTIONS":true
,"OR":true
,"ORD":true
,"ORDER":true
,"OTHERWISE":true
,"OUT":true
,"OUTER":true
,"OUTPUT":true
,"PAGE":true
,"PAGENO":true
,"PAUSE":true
,"PERCENT":true
,"PICTURE":true
,"PIPE":true
,"POPUP":true
,"PRECISION":true
,"PREPARE":true
,"PREVIOUS":true
,"PRIMARY":true
,"PRINT":true
,"PRINTER":true
,"PRINTX":true
,"PRIOR":true
,"PRIVATE":true
,"PRIVILEGES":true
,"PROCEDURE":true
,"PROGRAM":true
,"PROMPT":true
,"PUBLIC":true
,"PUT":true
,"QUIT":true
,"RAISE":true
,"READ":true
,"REAL":true
,"RECORD":true
,"RECOVER":true
,"RED":true
,"REFERENCES":true
,"RELATIVE":true
,"RELEASE":true
,"RENAME":true
,"REOPTIMIZATION":true
,"REPEATABLE":true
,"REPORT":true
,"RESOURCE":true
,"RESTART":true
,"RETAIN":true
,"RETURN":true
,"RETURNING":true
,"REVERSE":true
,"REVOKE":true
,"RIGHT":true
,"ROLLBACK":true
,"ROLLFORWARD":true
,"ROW":true
,"ROWBOUND":true
,"ROWS":true
,"RUN":true
,"SAVEPOINT":true
,"SCHEMA":true
,"SCREEN":true
,"SCROLL":true
,"SECOND":true
,"SELECT":true
,"SELECTION":true
,"SEQUENCE":true
,"SERIAL":true
,"SERIAL8":true
,"SET":true
,"SFMT":true
,"SHARE":true
,"SHIFT":true
,"SHORT":true
,"SHOW":true
,"SIGNAL":true
,"SITENAME":true
,"SIZE":true
,"SKIP":true
,"SLEEP":true
,"SMALLFLOAT":true
,"SMALLINT":true
,"SOME":true
,"SORT":true
,"SPACE":true
,"SPACES":true
,"SQL":true
,"SQLERRMESSAGE":true
,"SQLERROR":true
,"SQLSTATE":true
,"STABILITY":true
,"START":true
,"START_WITH":true
,"STATISTICS":true
,"STEP":true
,"STOP":true
,"STRING":true
,"STYLE":true
,"SUBDIALOG":true
,"SUM":true
,"SYNONYM":true
,"TABLE":true
,"TEMP":true
,"TERMINATE":true
,"TEXT":true
,"THEN":true
,"THROUGH":true
,"THRU":true
,"TIME":true
,"TIMER":true
,"TINYINT":true
,"TO":true
,"TODAY":true
,"TOP":true
,"TRAILER":true
,"TRANSACTION":true
,"TRUE":true
,"TRUNCATE":true
,"TRY":true
,"TYPE":true
,"UNBUFFERED":true
,"UNCONSTRAINED":true
,"UNDERLINE":true
,"UNION":true
,"UNIQUE":true
,"UNITS":true
,"UNLOAD":true
,"UNLOCK":true
,"UP":true
,"UPDATE":true
,"USER":true
,"USING":true
,"VALIDATE":true
,"VALUE":true
,"VALUES":true
,"VARCHAR":true
,"VIEW":true
,"WAIT":true
,"WAITING":true
,"WARNING":true
,"WEEKDAY":true
,"WHEN":true
,"WHENEVER":true
,"WHERE":true
,"WHILE":true
,"WHITE":true
,"WINDOW":true
,"WITH":true
,"WITHOUT":true
,"WORDWRAP":true
,"WORK":true
,"WRAP":true
,"XML":true
,"YEAR":true
,"YELLOW":true
,"YES":true
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
