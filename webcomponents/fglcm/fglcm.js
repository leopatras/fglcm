//short debugging helper in absence of gICAPI
m_syncLocal=false;
try {
  gICAPI;
} catch (e) {
  //m_syncLocal=true;
  gICAPI={};
  gICAPI.Action=function(aName) {
    console.log(">>gICAPI.Action('"+aName+"')");
  }
  gICAPI.SetData=function(value) {
    console.log(">>gICAPI.SetData('"+value+"')");
  }
}

var m_instance=0;
var m_inSetValue=false;
//var m_state=null;
var m_proparr=[];
var m_completionId=null;
var m_syncId=null;
var m_updateId=null;
var m_lines=[];
var m_orglines=[];
var m_removed=[]; //stores the removed lines
var m_initialLineCount=1;
var m_lineCount=1;
var m_crcTable=[];
var e_states = { initial:"initial",modified:"modified", inserted:"inserted" };
var m_annotations=[];
var m_editor=null;
var m_editorId=null;
var m_dataPending=false;
var m_updateOnData=null;
var m_prevFocus=null;

function initCRCTable(){
  var c;
  for(var n =0; n < 256; n++){
    c = n;
    for(var k =0; k < 8; k++){
        c = ((c&1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1));
    }
    m_crcTable[n] = c;
  }
}
initCRCTable();

function crc32(s) {
    var ba=toUtf8ByteArray(s);
    var code = 0 ^ (-1);
    var len=ba.length;
    for (var i = 0; i < len; i++ ) {
      var charcode=ba[i];
      code = (code >>> 8) ^ m_crcTable[(code ^ charcode) & 0xFF];
    }
    return (code ^ (-1)) >>> 0;
}

m_utf8encoder=null;
try {
  m_utf8encoder=new TextEncoder("utf-8");
} catch (err) {
  console.log("No TextEncoder:"+err.message);
}

function toUtf8ByteArray(str) {
  if (m_utf8encoder) {
    return m_utf8encoder.encode(str);
  }
  var out = [], p = 0;
  var len=str.length;
  for (var i = 0; i < len; i++) {
    var c = str.charCodeAt(i);
    if (c < 128) {
      out[p++] = c;
    } else if (c < 2048) {
      out[p++] = (c >> 6) | 192;
      out[p++] = (c & 63) | 128;
    } else if (
        ((c & 0xFC00) == 0xD800) && (i + 1) < str.length &&
        ((str.charCodeAt(i + 1) & 0xFC00) == 0xDC00)) {
      // Surrogate Pair
      c = 0x10000 + ((c & 0x03FF) << 10) + (str.charCodeAt(++i) & 0x03FF);
      out[p++] = (c >> 18) | 240;
      out[p++] = ((c >> 12) & 63) | 128;
      out[p++] = ((c >> 6) & 63) | 128;
      out[p++] = (c & 63) | 128;
    } else {
      out[p++] = (c >> 12) | 224;
      out[p++] = ((c >> 6) & 63) | 128;
      out[p++] = (c & 63) | 128;
    }
  }
  return out;
}

function initLines(doc) {
  var cnt=doc.lineCount();
  m_lines=[];
  for (var i=0;i<cnt;i++) {
    m_lines[i] = { state:e_states.initial , line:doc.getLine(i), orgnum:i };
    if (m_syncLocal) {
      m_orglines[i] = { state:e_states.initial , line:doc.getLine(i), orgnum:i };
    }
  }
  m_initialLineCount=cnt;
}

function setEditorValue(editor,txt) {
  m_inSetValue=true;
  editor.setValue(txt);
  m_inSetValue=false;
  initLines(editor.getDoc());
}

function coalesceIntArr(arr) {
  var lastIdx=-1;
  var resarr=[];
  arr.sort(function(a,b) {return a - b;});
  var len=arr.length;
  for(var i=0;i<len;i++) {
    var idx=arr[i];
    if (i<len-1 && arr[i+1]==idx+1) {
      if (lastIdx<0) {
        lastIdx=i;
      }
    } else {
      if (lastIdx>=0) {
        resarr.push({ idx: arr[lastIdx], len: i-lastIdx+1 });
      } else {
        resarr.push({ idx: arr[i], len: 1 });
      }
      lastIdx=-1;
    }
  }
  return resarr;
}

function sync() {
  var editor=m_editor;
  var modlines=[];
  //apply changes and collect inserts
  var lastOrgnum=-1;
  var inserts=[];
  var lastInsertChunk=[];
  //for (var i=m_lines.length-1;i>=0;i--) {}
  for (var i=0;i<m_lines.length;i++) {
    var line=m_lines[i];
    if (line.orgnum!==undefined) {
      if (lastInsertChunk.length>0) {
        inserts.push( { orgnum: lastOrgnum , ilines: lastInsertChunk } );
        lastInsertChunk=[];
      }
      lastOrgnum=line.orgnum;
    }
    if (line.state==e_states.modified && line.orgnum!==undefined) {
      var orgnum=line.orgnum;
      if (m_syncLocal && (orgnum<0 || orgnum>=m_orglines.length)) {
        console.log("!!line:"+i+",orgnum:"+orgnum+", m_orglines.length:'"+m_orglines.length+"'");
      } else {
        //console.log("add changed:"+JSON.stringify(line));
        console.log("patch line:"+orgnum+" with '"+line.line+ "'")
        if (m_syncLocal) {
          m_orglines[orgnum].line=line.line;
          line.state=e_states.initial;
        } else {
          modlines.push({ line:line.line, orgnum: orgnum });
        }
      }
    } else if (line.state==e_states.modified && line.orgnum===undefined) {
      lastInsertChunk.push({ line:line.line , orgnum: orgnum });      
    }
  }
  if (lastInsertChunk.length>0) {
    inserts.push( { orgnum: lastOrgnum , ilines: lastInsertChunk } );
  } 
  //removed
  var coalescedRemoves=coalesceIntArr(m_removed);
  if (m_syncLocal) {
    syncLocalRemovesAndInserts(coalescedRemoves,inserts);
  } else {
    var t0 = performance.now();
    var full=editor.getValue();
    var crc=crc32(full);
    var t1 = performance.now();
    console.log("crc32 took " + (t1 - t0) + " milliseconds.")
    var o={
      //full: editor.getValue(), //enable for debugging
      crc:crc,
      len:full.length,
      lineCount:editor.getDoc().lineCount(),
      modified: modlines,
      removed:coalescedRemoves,
      inserts:inserts,
      cursor1:editor.getCursor(true),
      cursor2:editor.getCursor(false),
      vm: false,
      locationhref: window.location.href
    }
    renumberLines();
    m_removed=[];
    return JSON.stringify(o);
  };
}

function fcsync() {
  return sync();
}

//only needed for testing without Genero
function syncLocalRemovesAndInserts(coalescedRemoves,inserts){
  //removed
  for (var i=coalescedRemoves.length-1;i>=0;i--) {
    var el=coalescedRemoves[i];
    m_orglines.splice(el.idx,el.len);
  }
  //inserts
  var j=0;
  console.log("inserts:",JSON.stringify(inserts));
  for(var i=0;i<inserts.length;i++) {
    var insert=inserts[i];
    var orgnum=insert.orgnum;
    for (;j<m_orglines.length;j++) {
      var line=m_orglines[j];
      console.log("line:"+j+",line orgnum:"+line.orgnum+",orgnum:"+orgnum);
      if (line.orgnum==orgnum) {
        var ilines=insert.ilines;
        for(var z=0;z<ilines.length;z++) {
          var newline=ilines[z];
          newline.orgnum=-1;
          var insertpos=j+z+1;
          console.log("insert new line at:"+insertpos+" with line:'"+newline.line+"'");
          m_orglines.splice(insertpos,0,newline);
        }
        break;
      }
    }
  }
  if (m_lines.length!==m_orglines.length) {
    console.log("m_lines.length:"+m_lines.length+",m_orglines.length:"+m_orglines.length);
  } else {
    var fail=false;
    for (var i=0;i<m_lines.length;i++) {
      var line=m_lines[i];
      var orgline=m_orglines[i];
      if (line.line!=orgline.line) {
        console.log("line:"+i+" '"+line.line+"' <> org:'"+orgline.line+"'");
        fail=true;
      }
    }
    if (!fail) {
      console.log("ok!!!");
    }
  }
}

function getFullTextAndRepair()
{
  var editor=m_editor;
  initLines(editor.getDoc());
  var full=editor.getValue();
  return full;
}

function renumberLines() {
  for(var i=m_lines.length-1;i>=0;i--) {
    var line=m_lines[i];
    line.state=e_states.initial;
    line.orgnum=i;
  }
}
function renumberOrgLines() {
  for(var i=m_orglines.length-1;i>=0;i--) {
    var line=m_orglines[i];
    line.orgnum=i;
    line.state=e_states.initial;
  }
}

function reset(editor) {
  //renumberOrgLines();
  //renumberLines();
  m_removed=[];
  m_orglines=[];
  m_lines=[];
  var s="";
  /*
  for (var i=1;i<4;i++) {
    s+= i + "\n";
  }*/
  if (m_syncLocal) {
    setEditorValue(editor,"--1\n--2\n--3\n--4");
  } else {
    setEditorValue(editor,s);
  }
}

//called whenever something is changed
/*
function fillValues(cm,o) {
  //o.full=cm.getValue();
  //o.full=(o.full===undefined)?null:o.full;
  o.cursor1=cm.getCursor(true);
  o.cursor2=cm.getCursor(false);
  //console.log("fillValues o:"+JSON.stringify(o));
}*/
function onChanges(cm,oarr) {
  console.log("onChanges, m_inSetValue:"+m_inSetValue);
}

function onChange(cm,o) {
  //console.log("onChange, m_inSetValue:"+m_inSetValue+",o:"+JSON.stringify(o));
  console.log("onChange, m_inSetValue:"+m_inSetValue);

  if (m_inSetValue) { return;}
  var fromLine=o.from.line;
  var toLine=o.to.line;
  var doc=cm.getDoc();
  for (var i=fromLine;i<=toLine;i++) {
    console.log("line "+i+" changed");
    m_lines[i].state=e_states.modified;
    m_lines[i].line=doc.getLine(i);
  }
  var orgremoved=o.removed;
  try {
    prepareRemoves(orgremoved,fromLine,toLine);
  } catch(err) {
    console.log("removed catch:"+err.message);
  }
  var orginserts=o.text;
  var len=orginserts.length;
  if (len>1) {
    var ilen=len-1;
    for(i=1;i<=ilen;i++) {
      m_lines.splice(fromLine+i,0,
        { state:e_states.modified, line:doc.getLine(fromLine+i), inserted:true });
    }
  }
  var cnt=doc.lineCount();
  if (m_lineCount!=cnt) {
    console.log("linecount changed from " + m_lineCount + " to "+cnt);
    m_lineCount=cnt;
  }
  //console.log("m_lines:"+JSON.stringify(m_lines));
  //fillValues(cm,o);
  //gICAPI.SetData(JSON.stringify(o));
  /*
  if (cm.state.completionActive) {
    console.log("completion active");
    clearSyncTimer(); 
    m_syncId = setTimeout(function() {
       sendChange(cm,"complete",true);
    },200);
  }
  */
  clearUpdateTimer();
  if (fIs4GLOrPer(cm.EXTENSION)) {
    if (m_dataPending) {
      console.log("data pending after onChange:set dolater");
      m_updateOnData=(m_updateOnData===null)?"update":m_updateOnData;
    } else {
      m_updateId = setTimeout(function() { checkUpdate("update");} ,cm.state.completionActive?200:500);
    }
  }
}

function prepareRemoves(orgremoved,fromLine,toLine) {
  if (orgremoved.length<1) {return;}
  var start=fromLine+1;
  for (var i=0;i<orgremoved.length-1;i++) {
    var idx=start+i;
    if (m_lines[idx].orgnum!==undefined) {
      //console.log("save remove org line:",idx);
      m_removed.push(m_lines[idx].orgnum);
    }
  }
  m_lines.splice(start,orgremoved.length-1);
}

function checkUpdate(what) {
  clearUpdateTimer();
  if (m_dataPending) {
    console.log("datapending in update");
    m_updateOnData=(m_updateOnData===null)?"update":m_updateOnData;
    return;
  }
  if (m_editor.state.completionActive) {
    sendChange(m_editor,"complete",true);
  } else {
    sendChange(m_editor,what,false);
  }
}

function checkUpdateOnData() {
  if (m_updateOnData===null) {
    return;
  }
  var what=m_updateOnData;
  m_updateOnData=null;
  checkUpdate(what);
}

function sendChange(cm,action,fromTimer) {
  //var o={};
  //onChange(cm,o);
  //alert("action:"+action);
  if (fromTimer) {
    console.log("sendChange fromTimer");
    clearSyncTimer();
    if (!cm.state.completionActive) {
      console.log("no completion active");
      return;
    }
  }
  m_dataPending=true;
  var data=sync();
  console.log("sendChange:"+data+",with action:"+action);
  gICAPI.SetData(data);
  gICAPI.Action(action);
  console.log("sendChange: finished");
}

function onKeyHandled(cm,name,ev) {
  //console.log("keyHandled:"+name);
}

function myAnnotations(text, options) {
  return m_annotations;
}

function fIs4GLOrPer(ext) {
  return (ext=="4gl" || ext=="per");
}

function createEditor(ext) {
   var ed=null;
   if (m_editor) {
     m_editor.toTextArea();
     ed=document.getElementById(m_editorId);
     ed.parentNode.removeChild(ed);
   }
   ed=document.createElement("TEXTAREA"); 
   m_instance++;
   m_editorId="editor"+m_instance;
   ed.id=m_editorId;
   document.body.appendChild(ed);
   var lint=true;
   //those keys are mostly for GBC because it can't handle them
   //via the TopMenu accelerators
   var extraKeys={
          "Alt-N":function(cm) {
            sendChange(cm,"new_cm",false);
            return false;
          },
          "Alt-O":function(cm) {
            sendChange(cm,"open_cm",false);
            return false;
          },
          "Alt-S":function(cm) {
            sendChange(cm,"save_cm",false);
            return false;
          },
          "Alt-Q":function(cm) {
            sendChange(cm,"close_cm",false);
            return false;
          },
          "Alt-L":function(cm) {
            sendChange(cm,"gotoline_cm",false);
            return false;
          },
          "Alt-F":function(cm) {
            CodeMirror.commands.findPersistent(cm);
            return false;
          },
          "Cmd-F":function(cm) {
            CodeMirror.commands.findPersistent(cm);
            return false;
          },
          "Alt-Cmd-F":function(cm) {
            CodeMirror.commands.replace(cm);
            return false;
          }
   };
   var is4GLOrPer=fIs4GLOrPer(ext);
   if (is4GLOrPer) {
     lint = { 'getAnnotations': myAnnotations, 'lintOnChange': false };
     extraKeys["Tab"] = function(cm) {
            //m_state="complete";
            if (m_dataPending) {
              console.log("Tab seen,data pending in completion");
              m_updateOnData="complete";
            } else {
              console.log("Tab seen,sending completion");
              sendChange(cm,"complete",false);
            }
            return false;
       };
   }
   if (ext=="js") {
      extraKeys["Tab"] = "autocomplete";
   }
   var modemap = {
     "4gl"    : "4gl",
     "js"     : "javascript",
     "42f"    : "xml",
     "fgldeb" : "xml",
     "4tb"    : "xml",
     "4tm"    : "xml",
     "4sm"    : "xml",
     "4st"    : "xml"
   }
   var mode=modemap[ext];
   if (mode===undefined) {
     mode=ext;
   }

   m_editor = CodeMirror.fromTextArea(ed, {
        lineNumbers: true,
        /*indentUnit: 2,*/
        /*scrollPastEnd: true,*/
        theme: "eclipse",
        mode: mode,
        autofocus:true,
        /*mylint: true,*/
        lint: lint,
        /*keyMap: "vim",*/
        matchBrackets: true,
        gutters: ["CodeMirror-lint-markers"],
        showCursorWhenSelecting: true,
        extraKeys: extraKeys
  });
  var doc=new CodeMirror.Doc("", mode );
  m_editor.EXTENSION=ext; //just glue our 4GL side extension var to the editor
  m_editor.setOption("fullScreen",true);
  m_editor.on("change",onChange);
  m_editor.on("changes",onChanges);
  reset(m_editor);
  //m_editor.focus();
}
createEditor("4gl");
//editor.on("keyHandled",onKeyHandled);
function isInPropArr(txt) {
  for(var i=0;i<m_proparr.length;i++) {
    if(m_proparr[i]===txt) {
      return true;
    }
  }
  return false;
}

function get4GLHint(cm, c) {
   var cursor=cm.getCursor();
   var word = cm.findWordAt(cursor);
   console.log("word:"+JSON.stringify(word));
   var txt=cm.getRange(word.anchor, word.head);
   var re_noalnum=/^["'\^%\*\-\+,= \\/\.\[\](){};]+$/;
   var isAlNum=true;
   if (txt.length>=1 && re_noalnum.test(txt)) {
     if (word.anchor.ch<cursor.ch) {
       //var nextCursor=new CodeMirror.Pos(cursor.line,cursor.ch+1);
       //txt=cm.getRange(cursor, nextCursor);
       console.log("word is noalnum");
       isAlNum=false;
       word.head=cursor;
       word.anchor=cursor;
     }
   }
   console.log("txt:'"+txt+"'");
   var foundeq=false;
   if (cursor.ch>0 && isAlNum) {
     var prevCursor=new CodeMirror.Pos(cursor.line,cursor.ch-1);
     var word2=cm.findWordAt(prevCursor);
     var txt2=cm.getRange(word2.anchor, word2.head);
     console.log("txt2:'"+txt2+"'");
     if ((txt=="." && txt2==".")||(txt=='"' && txt2=='"')) {
       word.head=word.anchor=new CodeMirror.Pos(cursor.line,cursor.ch+1);
     } else if (re_noalnum.test(txt) /*|| isInPropArr(txt2)*/) {
       if (txt!=txt2) {
         console.log("switch to word2:"+txt2);
         word=word2;
         txt=txt2;
       } else {
         foundeq=isInPropArr(txt);
       }
     }
   }
   if(foundeq || /^\s+$/.test(txt)) { //we found only spaces
     word.anchor=word.head;
   }
   return {list: m_proparr,
           from:word.anchor, to:word.head };
}

/*
function getData() {
  var o={};
  fillValues(m_editor,o);
  return JSON.stringify(o);
}*/

function clearCompletionAliveTimer() {
  if (m_completionId!==null) { 
    clearTimeout(m_completionId); 
    m_completionId=null; 
  }
}

function clearSyncTimer() {
  if (m_syncId!==null) { 
    clearTimeout(m_syncId); 
    m_syncId=null; 
  }
}

function clearUpdateTimer() {
  if (m_updateId!==null) { 
    clearTimeout(m_updateId); 
    m_updateId=null; 
  }
}

onICHostReady = function(version) {
   //console.log("onICHostReady");
   gICAPI.onFocus = function(setFocus) {
     if (setFocus&&m_editor) {
       m_editor.focus();
     }
   }
   gICAPI.onData = function(data) {
     //alert("onData:"+data);
     console.log("onData:"+data+",m_updateOnData:"+m_updateOnData);
     if (data===undefined || data===null) {
       alert("onData with undefined or null, check your code!!!");
       return;
     }
     var o=JSON.parse(data);
     //console.log("onData m_state:"+m_state+",data:"+data);
     if (!o.vm) { //change was not issued by 4GL side ..GBC problem???
       //checkUpdateOnData();
       return;
     } 
     m_dataPending=false; 
     if (o.extension!==undefined) {
       if (m_editor.EXTENSION!=o.extension) {
         console.log("extension changed from:"+m_editor.EXTENSION+" to:",o.extension);
         createEditor(o.extension);
       }
     }
     if (o.proparr!==undefined) {
       console.log("prepareCompletion");
       //alert("complete arr:"+data);
       m_proparr=o.proparr; //we preserve the completion list
       clearCompletionAliveTimer();
       m_completionId = setTimeout(function() {
           m_editor.showHint({hint: get4GLHint});
         },50);
     }
     //alert("data:"+data);
     if (o.full!==undefined) {
       if ((o.fileName!==undefined && o.fileName!=m_editor.FILENAME) ||
            o.cmCommand=="reload" ) {
         console.log("would swap doc");
         var doc=new CodeMirror.Doc(o.full,m_editor.getMode());
         m_editor.swapDoc(doc);
         m_editor.FILENAME=o.fileName;
         initLines(doc);
       } else if (o.full!==m_editor.getValue()) {
         setEditorValue(m_editor,o.full);
       }
     }
     if (o.cursor1!==undefined) {
       console.log("set cursor");
       if (o.cursor2===undefined) {
         o.cursor2=o.cursor1;
       }
       m_editor.setSelection( o.cursor1,o.cursor2 );
     }
     if (o.annotations!==undefined) {
       m_annotations=o.annotations;
       m_editor.performLint();
     } else {
       m_annotations=[];
       m_editor.performLint();
     }
     if (o.cmCommand=="find") {
       CodeMirror.commands.findPersistent(m_editor);
     } else if (o.cmCommand=="replace") {
       CodeMirror.commands.replace(m_editor);
     }
     checkUpdateOnData();
     //m_editor.focus();
   }

   gICAPI.onProperty = function(p) {
     //var o = eval('(' + p + ')');
     //console.log(JSON.stringify(o));
   }
}
/*
function tryMarkers() {
  m_annotations=[ { from: new CodeMirror.Pos(1,0),to: new CodeMirror.Pos(1,2), severity: "error",message:"@blaba" } ];
  //window.updateMarkers(m_editor,annotations);
  m_editor.performLint();
}
setInterval(function(){ 
  var e=document.activeElement;
  if (e) {
    console.log("focus:"+e.tagName+",id:"+e.id+",className:"+e.className);
  }
}, 1000);
*/
//reset(m_editor);
