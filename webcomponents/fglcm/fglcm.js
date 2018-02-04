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

var m_inSetValue=false;
var m_state=null;
var proparr=[];
var m_completionId=null;
var m_syncId=null;
var m_lines=[];
var m_orglines=[];
var m_removed=[]; //stores the removed lines
var m_initialLineCount=1;
var m_lineCount=1;
var m_crcTable=[];
var e_states = { initial:"initial",modified:"modified", inserted:"inserted" };

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
    var code = 0 ^ (-1);
    var len=s.length;
    for (var i = 0; i < len; i++ ) {
      var charcode=s.charCodeAt(i);
      code = (code >>> 8) ^ m_crcTable[(code ^ charcode) & 0xFF];
    }
    return (code ^ (-1)) >>> 0;
}

function setEditorValue(editor,txt) {
  m_inSetValue=true;
  editor.setValue(txt);
  m_inSetValue=false;
  var doc=editor.getDoc();
  var cnt=doc.lineCount();
  for (var i=0;i<cnt;i++) {
    m_lines[i] = { state:e_states.initial , line:doc.getLine(i), orgnum:i };
    if (m_syncLocal) {
      m_orglines[i] = { state:e_states.initial , line:doc.getLine(i), orgnum:i };
    }
  }
  m_initialLineCount=cnt;
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
    var full=editor.getValue();
    var crc=crc32(full);
    var o={
      //full: editor.getValue(), //enable for debugging
      crc: crc,
      modified: modlines,
      removed:coalescedRemoves,
      inserts:inserts,
      cursor1:editor.getCursor(true),
      cursor2:editor.getCursor(false),
      vm: false
    }
    renumberLines();
    m_removed=[];
    gICAPI.SetData(JSON.stringify(o));
  };
}

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

function reset() {
  renumberOrgLines();
  renumberLines();
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
function fillValues(cm,o) {
  //o.full=cm.getValue();
  //o.full=(o.full===undefined)?null:o.full;
  o.cursor1=editor.getCursor(true);
  o.cursor2=editor.getCursor(false);
  //console.log("fillValues o:"+JSON.stringify(o));
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
  } catch(msg) {
    console.log("removed catch:"+msg);
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
  fillValues(cm,o);
  //gICAPI.SetData(JSON.stringify(o));
  if (editor.state.completionActive) {
    console.log("completion active");
    m_syncId = setTimeout(function() {
       sendChange(cm,"complete",true);
    },200);
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
  sync();
  gICAPI.Action(action);
}

function onKeyHandled(cm,name,ev) {
  //console.log("keyHandled:"+name);
}

var editor = CodeMirror.fromTextArea(document.getElementById("editor"), {
        lineNumbers: true,
        /*indentUnit: 2,*/
        /*scrollPastEnd: true,*/
        theme: "eclipse",
        mode: "text/x-4gl",
        autofocus:true,
        /*keyMap: "vim",*/
        matchBrackets: true,
        showCursorWhenSelecting: true
        ,
        extraKeys: {
          "Cmd-S":function(cm) {
            sendChange(cm,"sync",false);
            return false;
          }
          ,
          "Tab":function(cm) {
            m_state="complete";
            sendChange(cm,"complete",false);
            return false;
          } 
        }
});
editor.setOption("fullScreen",true);
editor.on("change",onChange);
//editor.on("keyHandled",onKeyHandled);

//not much to do here, we just check if we
//have spaces under the cursor
function get4GLHint(cm, c) {
   var cursor=cm.getCursor();
   var word = cm.findWordAt(cursor);
   console.log("word:"+JSON.stringify(word));
   var txt=cm.getRange(word.anchor, word.head);
   console.log("txt:'"+txt+"'");
   var foundeq=false;
   if (cursor.ch>0) {
     var prevCursor=new CodeMirror.Pos(cursor.line,cursor.ch-1);
     var word2=cm.findWordAt(prevCursor);
     var txt2=cm.getRange(word2.anchor, word2.head);
     console.log("txt2:'"+txt2+"'");
     if (txt=="=") {
       if (txt!=txt2) {
         console.log("switch to word2:"+txt2);
         word=word2;
         txt=txt2;
       } else {
         for(var i=0;i<proparr.length;i++) {
           if(proparr[i]="=") {
             foundeq=true;
             break;
           }
         }
       }
     }
   }
   if(foundeq || /^\s+$/.test(txt)) { //we found only spaces
     word.anchor=word.head;
   }
   return {list: proparr,
           from:word.anchor, to:word.head };
}

function getData() {
  var o={};
  fillValues(editor,o);
  return JSON.stringify(o);
}

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

onICHostReady = function(version) {
   //console.log("onICHostReady");
   gICAPI.onFocus = function(polarity) {
   }
   gICAPI.onData = function(data) {
     var o=JSON.parse(data);
     console.log("onData m_state:"+m_state+",data:"+data);
     if (o.proparr!==undefined) {
       //alert("complete arr:"+data);
       proparr=o.proparr; //we preserve the completion list
       clearCompletionAliveTimer();
       m_completionId = setTimeout(function() {
           editor.showHint({hint: get4GLHint});
         },50);
     }
     if (!o.vm) { return;} //VM has no changes
     //alert("data:"+data);
     if (o.full!==undefined) {
       if (o.full!==editor.getValue()) {
         setEditorValue(editor,o.full);
       }
     }
     if (o.cursor1.line!==undefined) {
       console.log("set cursor");
       editor.setSelection( o.cursor1,o.cursor2 );
     }
   }

   gICAPI.onProperty = function(p) {
     var o = eval('(' + p + ')');
     console.log(JSON.stringify(o));
   }
}

//setEditorValue(editor,"1\n2\n3\n4\n5\n6");

//setEditorValue(editor,"1\n2\n3");
reset();