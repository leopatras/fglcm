//short debugging helper in absence of gICAPI
var m_syncLocal=false;
var m_syncNum=0;
var m_logStr="";
var m_active=false;
var m_data=null;
var m_dataId=null;
function mylog(s) {
  m_logStr=(m_logStr=="")?s:(m_logStr+"\n"+s);
  console.log(s);
}
function myErr(s) {
  mylog("ERROR:"+s);
  alert("ERROR:"+s);
}

try {
  gICAPI;
} catch (e) {
  //m_syncLocal=true;
  gICAPI={};
  gICAPI.Action=function(aName) {
    mylog(">>gICAPI.Action('"+aName+"')");
  }
  gICAPI.SetData=function(value) {
    mylog(">>gICAPI.SetData('"+value+"')");
  }
}

function getEvTarget(ev) {
  if (!ev) {
    return undefined;
  }
  if(ev.REPLAYTARGET) { return ev.REPLAYTARGET; }
  return ev.target ? 
    ((ev.target.nodeType==3)?ev.target.parentElement:ev.target)
    : ev.srcElement;
}

function printEl(el) {
  if (!el) { return "no el"; }
  return el.tagName+",id:"+el.id;
}

function printFocus() {
  return printEl(document.activeElement);
}

function getKeyVal(ev) { 
  return String.fromCharCode(ev.keyCode); 
}

function printEv(ev,what) {
  var target = getEvTarget(ev);
  var tagName=target?target.tagName:"unknown";
  var id=target?target.id:"unknown";
  //  if ( e.type == "keydown" ) { try { e.keyCode = 0 } catch(x) {} }
  try {
  mylog(what+(what?" ":"")+"event target:"+tagName+",id:"+ id +
      ",type:" + ev.type     +
      ",keyCode:"       + ev.keyCode  +
      ",charCode:"      + ev.charCode  +
      ",which:"         + ev.which  +
      ",keyVal:"        + getKeyVal(ev)  +
      ",altKey:"        + ev.altKey   +
      ",altKey:"        + ev.altKey   +
      ",shiftKey:"      + ev.shiftKey +
      ",ctrlKey:"       + ev.ctrlKey  +
      ",metaKey:"       + ev.metaKey  +
      ",clientX:"       + ev.clientX  +
      ",clientY:"       + ev.clientY  +
      ",screenX:"       + ev.screenX  +
      ",screenY:"       + ev.screenY +
      ",activeEl:"      + printFocus()
      );
   } catch(x) {
     mylog("failure:"+x.message);
   }
  /*
     for(i in ev) {
     mylog("ev:"+i+"="+ev[i]);
     }*/
}

function toNavigationKey(ev) {
   var code=ev.keyCode;
   var k="";
   switch (code) {
    case 8: k="BackSpace";break;
    case 9: k=ev.shiftKey?"Shift-Tab":"Tab";break;
    case 13: k=ev.shiftKey?"Shift-Return":"Return";break;
    case 33:
      k="prevpage";break;
    case 34:
      k="nextpage";break;
    case 38:k="Up";break;
    case 40:k="Down";break;
    case 37:k="Left";break;
    case 39:k="Right";break;
    case 36:
      k="Home";
      break;
    case 35:
      k="End";
      break;
    case 46:
      k="Delete";
      break;
   } 
   return k;
}

function handleKeyDown(ev) { //global keydown handler
  printEv(ev,"handleKeyDown");
  var k = toNavigationKey(ev);
  mylog("k:"+k);
  /*
  if (k!=="") {
    CodeMirror.e_stop(ev);
  }*/
}

function handleStop(ev) {
  CodeMirror.e_stop(ev);
}

CodeMirror.on(document,"keydown",handleKeyDown);
//CodeMirror.on(document,"keypress",handleStop);
//CodeMirror.on(document,"keyup",handleStop);

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
var m_fglcm_init=false;
//for debugging get4GLHint
//var m_lastseen = performance.now(); 
var m_repairCount = 0;
//can be set via FGLCM_FLUSHTIMEOUT
var m_flushTimeout = 1000;
var m_lastChanges=null;
var m_InAction=false;
var m_search_history=[];
var m_search_idx=-1;
var m_cmdIdx=-1;
//var m_lastData="";

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
  mylog("No TextEncoder:"+err.message);
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
        mylog("!!line:"+i+",orgnum:"+orgnum+", m_orglines.length:'"+m_orglines.length+"'");
      } else {
        //mylog("add changed:"+JSON.stringify(line));
        mylog("patch line:"+orgnum+" with '"+line.line+ "'")
        if (m_syncLocal) {
          m_orglines[orgnum].line=line.line;
          line.state=e_states.initial;
        } else {
          modlines.push({ line:line.line, orgnum: orgnum });
        }
      }
    } else if (line.state==e_states.modified && line.orgnum===undefined) {
      line.line=editor.getDoc().getLine(i);
      lastInsertChunk.push({ line:line.line , orgnum: i });
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
    var lineCount=editor.getDoc().lineCount();
    var len=full.length;
    var crc=crc32(full);
    var t1 = performance.now();
    mylog("crc32 took " + (t1 - t0) + " milliseconds.")
    m_syncNum++; //first time:1
    var syncNum=m_syncNum;
    var o={
      //full: editor.getValue(), //enable for debugging
      crc:crc,
      len:len,
      lineCount:lineCount,
      modified: modlines,
      removed:coalescedRemoves,
      inserts:inserts,
      cursor1:editor.getCursor(true),
      cursor2:editor.getCursor(false),
      vm: false,
      locationhref: window.location.href,
      syncNum:syncNum
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
  mylog("inserts:",JSON.stringify(inserts));
  for(var i=0;i<inserts.length;i++) {
    var insert=inserts[i];
    var orgnum=insert.orgnum;
    for (;j<m_orglines.length;j++) {
      var line=m_orglines[j];
      mylog("line:"+j+",line orgnum:"+line.orgnum+",orgnum:"+orgnum);
      if (line.orgnum==orgnum) {
        var ilines=insert.ilines;
        for(var z=0;z<ilines.length;z++) {
          var newline=ilines[z];
          newline.orgnum=-1;
          var insertpos=j+z+1;
          mylog("insert new line at:"+insertpos+" with line:'"+newline.line+"'");
          m_orglines.splice(insertpos,0,newline);
        }
        break;
      }
    }
  }
  if (m_lines.length!==m_orglines.length) {
    mylog("m_lines.length:"+m_lines.length+",m_orglines.length:"+m_orglines.length);
  } else {
    var fail=false;
    for (var i=0;i<m_lines.length;i++) {
      var line=m_lines[i];
      var orgline=m_orglines[i];
      if (line.line!=orgline.line) {
        mylog("line:"+i+" '"+line.line+"' <> org:'"+orgline.line+"'");
        fail=true;
      }
    }
    if (!fail) {
      mylog("ok!!!");
    }
  }
}

function getFullTextAndRepair()
{
  var editor=m_editor;
  var full=editor.getValue();
  m_repairCount++;
  var doc=editor.getDoc();
  var cnt=doc.lineCount();
  initLines(doc);
  return JSON.stringify({full:full,crc32: crc32(full),lastChanges:JSON.stringify(m_lastChanges),lineCount:cnt,log:getLog()});
}

function getLog() {
  var log=m_logStr;
  m_logStr="";
  return log;
}

function qaGetFullText()
{
  var editor=m_editor;
  return editor.getValue();
}

function qaGetInit()
{
  return m_fglcm_init?1:0;
}

function qaGetDataPending()
{
  return m_dataPending?1:0;
}

function qaGetCompletionId()
{
  return m_completionId!==null?m_completionId:"(null)";
}

function qaGetDOMFocus()
{
  var el=document.activeElement;
  if (!el) {
    return '{tagName:"none", className:"none", id:"none"}';
  }
  var ret='{tagName:"'+el.tagName+'", className:"'+el.className+'", id:"'+el.id+'"}';
  return ret;
}

function qaGetRepairCount()
{
  return m_repairCount;
}

function isVisible(el) {
  var style = window.getComputedStyle(el);
  return (style.display !== 'none')
}

function qaGetHintsVisible()
{
  var arr=document.getElementsByClassName("CodeMirror-hints");
  mylog("arr.length:",arr.length);
  if (arr.length===1) {
    return isVisible(arr[0])?1:0;
  }
  return 0;
}

function qaSendInput(txt,timeout)
{
  if (timeout===undefined) {
    timeout=500;
  }
  setTimeout(function() {
    m_editor.setValue(txt);
  },timeout);  
}

function qaSendAction(actionName,timeout)
{
  if (timeout===undefined) {
    timeout=500;
  }
  setTimeout(function() {
    myAction(actionName);
  },timeout);
}

function renumberLines() {
  for(var i=m_lines.length-1;i>=0;i--) {
    var line=m_lines[i];
    line.state=e_states.initial;
    line.orgnum=i;
    delete line.inserted;
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
  //mylog("fillValues o:"+JSON.stringify(o));
}*/
function onChanges(cm,oarr) {
  mylog("onChanges, m_inSetValue:"+m_inSetValue);
  //the trace of the inserts is needed for the block sel ops
  //(block sel and then hit Return)
  var inserted=0;
  m_lastChanges=oarr;
  for (var i=0;i<oarr.length;i++){
    inserted=onChange(cm,oarr[i],inserted);
  }
}

function onChange(cm,o,inserted) {
  //mylog("onChange, m_inSetValue:"+m_inSetValue+",o:"+JSON.stringify(o));
  mylog("onChange, m_inSetValue:"+m_inSetValue+",inserted:"+inserted);

  if (m_inSetValue) { return;}
  var fromLine=o.from.line;
  var toLine=o.to.line;
  var doc=cm.getDoc();
  var mlen=m_lines.length;
  for (var i=fromLine;i<=toLine&&i<mlen;i++) {
    //mylog("line "+i+" changed");
    m_lines[i].state=e_states.modified;
    m_lines[i].line=doc.getLine(i);
  }
  var orgremoved=o.removed;
  try {
    prepareRemoves(orgremoved,fromLine,toLine);
  } catch(err) {
    mylog("removed catch:"+err.message);
  }
  var orginserts=o.text;
  var len=orginserts.length;
  if (len>1) {
    fromLine+=inserted;
    var ilen=len-1;
    for(i=1;i<=ilen;i++) {
      inserted+=1;
      m_lines.splice(fromLine+i,0,
        { state:e_states.modified, line:doc.getLine(fromLine+i), inserted:true });
    }
  }
  var cnt=doc.lineCount();
  if (m_lineCount!=cnt) {
    mylog("linecount changed from " + m_lineCount + " to "+cnt);
    m_lineCount=cnt;
  }
  //mylog("m_lines:"+JSON.stringify(m_lines));
  //fillValues(cm,o);
  //gICAPI.SetData(JSON.stringify(o));
  /*
  if (cm.state.completionActive) {
    mylog("completion active");
    clearSyncTimer(); 
    m_syncId = setTimeout(function() {
       sendChange(cm,"complete",true);
    },200);
  }
  */
  clearUpdateTimer();
  if (fIs4GLOrPer(cm.EXTENSION)) {
    if (m_dataPending) {
      mylog("data pending after onChange:set dolater");
      m_updateOnData=(m_updateOnData===null)?"update":m_updateOnData;
    } else {
      m_updateId = setTimeout(function() { checkUpdate("update");} ,cm.state.completionActive?100:m_flushTimeout);
    }
  }
  return inserted;
}

function prepareRemoves(orgremoved,fromLine,toLine) {
  if (orgremoved.length<1) {return;}
  var start=fromLine+1;
  for (var i=0;i<orgremoved.length-1;i++) {
    var idx=start+i;
    if (m_lines[idx].orgnum!==undefined) {
      //mylog("save remove org line:",idx);
      m_removed.push(m_lines[idx].orgnum);
    }
  }
  m_lines.splice(start,orgremoved.length-1);
}

function checkUpdate(what) {
  clearUpdateTimer();
  if (m_dataPending || !m_active) {
    //we must not send updates if the VM side has data pending or isn't receiving 
    mylog("checkUpdate: datapending:"+m_dataPending+" || !m_active:"+!m_active);
    m_updateOnData=(m_updateOnData===null)?"update":m_updateOnData;
    return;
  }
  if (m_editor.state.completionActive) {
    sendChange(m_editor,"complete",true);
  } else {
    sendChange(m_editor,what,false);
  }
}

function checkUpdateOnData(o) {
  if (o.feedAction!=null) {
    mylog("feed action:"+o.feedAction);
    m_updateOnData=o.feedAction;
  }
  if (m_updateOnData===null) {
    return;
  }
  var what=m_updateOnData;
  m_updateOnData=null;
  checkUpdate(what);
}

function myAction(a) {
  mylog("before gICAPI.Action:"+a);
  m_InAction=true;
  gICAPI.Action(a);
  m_InAction=false;
  mylog("after gICAPI.Action:"+a);
}

function sendChange(cm,action,fromTimer) {
  //var o={};
  //onChange(cm,o);
  //alert("action:"+action);
  if (fromTimer) {
    mylog("sendChange fromTimer");
    clearSyncTimer();
    if (!cm.state.completionActive) {
      mylog("no completion active");
      return;
    }
  }
  m_dataPending=true;
  var data=sync();
  mylog("sendChange:"+data+",with action:"+action);
  gICAPI.SetData(data);
  //m_lastData=data;
  myAction(action);
  mylog("sendChange: finished");
}

function onKeyHandled(cm,name,ev) {
  //mylog("keyHandled:"+name);
}

function myAnnotations(text, options) {
  return m_annotations;
}

function fIs4GLOrPer(ext) {
  return (ext=="4gl" || ext=="per");
}

function lineEmptyUntilCursor(cm)
{
  var doc=cm.getDoc();
  var cursor=doc.getCursor();
  var linenum=cursor.line;
  var linepart=doc.getLine(linenum).substr(0,cursor.ch);
  mylog("line part is "+linepart.length+ " spaces");
  return /^\s*$/.test(linepart);
}

function myComplete(cm,cleverTab)
{
  //m_state="complete";
  if (m_dataPending) {
    mylog("Tab seen,data pending in completion");
    m_updateOnData="complete";
  } else {
    mylog("Tab seen,sending completion");
    if (cleverTab && lineEmptyUntilCursor(cm)) {
      mylog("insertSoftTab")
      CodeMirror.commands.insertSoftTab(cm);
    } else {
      clearUpdateTimer();
      sendChange(cm,"complete",false);
    }
  }
}

function findWordUnderCursor(cm) {
   var c=cm.getCursor();
   var word=cm.findWordAt(c);
   var doc=cm.getDoc();
   var txt=doc.getRange(word.anchor,word.head)
   doc.extendSelection(word.anchor, word.head);
   //var txt=doc.getSelection();
   mylog("txt:"+txt);
   // /\b(word)\b/g word boundary
   /*
   var cursor=cm.getSearchCursor(txt, c, {caseFold: false});
   //CodeMirror.commands.findPersistent(cm);
   if (!cursor.findNext()) {
      alert("did not find:"+txt);
      return;
   }
   cm.setSelection(cursor.from(), cursor.to());
   cm.scrollIntoView({from: cursor.from(), to: cursor.to()}, 20);
   */
   CodeMirror.commands.findNext(cm);
   //doc.getRange(word.anchor,word.head)

}

function insertIntoSearchHistory(val) {
  var idx=m_search_history.indexOf(val);
  mylog("history before insert:"+val+" "+JSON.stringify(m_search_history));
  mylog("idx:"+idx);
  if (idx> -1) { //remove at found index
    m_search_history.splice(idx,1);
  }
  m_search_history.splice(0,0,val); //insert at first pos
  mylog("history after insert:"+val+" "+JSON.stringify(m_search_history));
  m_search_idx=-1;
}

function searchHistoryUp(prevEntry) {
  var entry="";
  if (m_search_history.length==0) {
    return prevEntry;
  }
  m_search_idx=m_search_idx+1;
  if (m_search_idx>m_search_history.length-1) {
    m_search_idx=m_search_history.length-1;
  }
  if (m_search_idx>=0) {
    entry=m_search_history[m_search_idx];
  }
  if (entry==prevEntry &&
     m_search_history.length>0 && m_search_idx<m_search_history.length-1) {
    //the value didnt change
    return searchHistoryUp(prevEntry);
  }
  return entry;
}

function searchHistoryDown(prevEntry) {
  var entry="";
  if (m_search_history.length==0) {
    return prevEntry;
  }
  m_search_idx=m_search_idx-1  
  if (m_search_idx<-1) {
    m_search_idx=-1;
  } else if (m_search_idx>m_search_history.length-1) {
    m_search_idx=m_search_history.length-1;
  }
  if (m_search_idx>=0) {
    entry=m_search_history[m_search_idx];
  }
  return entry;
}

function handleKeyDownSearch(ev) {
  printEv(ev,"handleKeyDownSearch");
  var target=getEvTarget(ev);
  var k = toNavigationKey(ev);
  mylog("k:"+k);
  if (k=="Return" || k=="Shift-Return") {
    var val=target.value;
    mylog("Search:"+val);
    insertIntoSearchHistory(val);
  } else if (k=="Up") {
    target.value=searchHistoryUp(target.value);
    CodeMirror.e_stop(ev);
  } else if (k=="Down") {
    target.value=searchHistoryDown(target.value);
    CodeMirror.e_stop(ev);
  }
}

function clearDialog() {
  if (getDialog()) {
    m_editor.focus(); //causes destroy of curr dlg 
  }
}

function searchDialogActive() {
  var dlg=getDialog();
  return (dlg && dlg["data-searchdlg"]===true);
}

function findPersistent(cm) {
  clearDialog();
  CodeMirror.commands.findPersistent(cm);
  var inp=document.activeElement;
  if (inp && inp.tagName=="INPUT") {
    var dlg=getDialog();
    dlg["data-searchdlg"]=true;
    mylog("add keydown listener:"+printEl(inp));
    try {
      CodeMirror.off(inp,"keydown",handleKeyDown);
    } catch (msg) {
      mylog("CodeMirror.off failed:"+msg.message);
    }
    CodeMirror.on(inp,"keydown",handleKeyDownSearch);
    m_search_idx=-1;
  }
}

function doReplace(cm) {
  clearDialog();
  CodeMirror.commands.replace(cm);
}

function createEditor(ext) {
   var ed=null;
   if (m_editor) {
     m_editor.toTextArea();
     ed=document.getElementById(m_editorId);
     ed.parentNode.removeChild(ed);
   }
   ed=document.createElement("TEXTAREA");
   ed.className="fglcm_editor";
   m_instance++;
   m_editorId="editor"+m_instance;
   ed.id=m_editorId; //doesn't work
   document.body.appendChild(ed);
   var lint=true;
   //those keys are mostly for GBC because it can't handle them
   //via the TopMenu accelerators
   var extraKeys={
          "Alt-N":function(cm) {
            sendChange(cm,"new",false);
            return false;
          },
          "Alt-O":function(cm) {
            sendChange(cm,"open",false);
            return false;
          },
          "Alt-S":function(cm) {
            sendChange(cm,"save",false);
            return false;
          },
          "Alt-Q":function(cm) {
            sendChange(cm,"close",false);
            return false;
          },
          "Alt-L":function(cm) {
            sendChange(cm,"gotoline",false);
            return false;
          },
          "Alt-T":function(cm) {
            sendChange(cm,"format_src",false);
            return false;
          },
          "Alt-F":function(cm) {
            findPersistent(cm);
            return false;
          },
          "Cmd-F":function(cm) {
            findPersistent(cm);
            return false;
          },
          "Alt-Cmd-F":function(cm) {
            doReplace(cm);
            return false;
          },
          "Alt-W": function(cm) {
            findWordUnderCursor(cm);
            return false;
          }
   };
   extraKeys["Ctrl-N"]=extraKeys["Alt-N"];
   extraKeys["Ctrl-O"]=extraKeys["Alt-O"];
   extraKeys["Ctrl-S"]=extraKeys["Alt-S"];
   extraKeys["Ctrl-F"]=extraKeys["Alt-F"];
   extraKeys["Ctrl-Q"]=extraKeys["Alt-Q"];
   extraKeys["Ctrl-L"]=extraKeys["Alt-L"];
   extraKeys["Ctrl-T"]=extraKeys["Alt-T"];
   extraKeys["Ctrl-W"]=extraKeys["Alt-W"];
   var is4GLOrPer=fIs4GLOrPer(ext);
   if (is4GLOrPer) {
     lint = { 'getAnnotations': myAnnotations, 'lintOnChange': false };
     extraKeys["Tab"] = function(cm) {
       myComplete(cm,true);//clever tab
       return false;
     };
     extraKeys["Ctrl-Space"]= function(cm) {
       myComplete(cm,false);//always completes
       return false;
     }
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
        lineWrapping: true,
        styleActiveLine: true,
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
   /*
   var t1 = performance.now();
   var diff= t1-m_lastseen;
   mylog("diff:"+diff);
   if (diff<1000) {
     //alert("get4GLHint");
   }
   m_lastseen=t1;
   */
   var cursor=cm.getCursor();
   var word = cm.findWordAt(cursor);
   mylog("word:"+JSON.stringify(word));
   var txt=cm.getRange(word.anchor, word.head);
   var re_noalnum=/^["'\^%\*\-\+,= \\/\.\[\](){};]+$/;
   var isAlNum=true;
   if (txt.length>=1 && re_noalnum.test(txt)) {
     if (word.anchor.ch<cursor.ch) {
       //var nextCursor=new CodeMirror.Pos(cursor.line,cursor.ch+1);
       //txt=cm.getRange(cursor, nextCursor);
       mylog("word is noalnum");
       isAlNum=false;
       word.head=cursor;
       word.anchor=cursor;
     }
   }
   mylog("txt:'"+txt+"'");
   var foundeq=false;
   if (cursor.ch>0 && isAlNum) {
     var prevCursor=new CodeMirror.Pos(cursor.line,cursor.ch-1);
     var word2=cm.findWordAt(prevCursor);
     var txt2=cm.getRange(word2.anchor, word2.head);
     mylog("txt2:'"+txt2+"'");
     if ((txt=="." && txt2==".")||(txt=='"' && txt2=='"')) {
       word.head=word.anchor=new CodeMirror.Pos(cursor.line,cursor.ch+1);
     } else if (re_noalnum.test(txt) /*|| isInPropArr(txt2)*/) {
       if (txt!=txt2) {
         mylog("switch to word2:"+txt2);
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

function clearDataTimer() {
  if (m_dataId!==null) { 
    clearTimeout(m_dataId); 
    m_dataId=null; 
  }
}

function setEditorEnabled(enabled) {
  if (m_editor===null) { return; }
  m_editor.setOption("readOnly", enabled ? false : "nocursor");
  const classList = m_editor.getWrapperElement().classList;
  classList[enabled ? "remove" : "add"]("disabled");
}

function getDialog() {
  if (!m_editor) {
    return false;
  }
  return m_editor.getWrapperElement().querySelector(".CodeMirror-dialog");
}

onICHostReady = function(version) {
   //mylog("onICHostReady");
   gICAPI.onFocus = function(setFocus) {
     mylog("onFocus:"+setFocus);
     if (setFocus&&m_editor) {
       mylog("editor setFocus");
       m_editor.focus();
     }
   }
   scheduleProcessData=function() {
     //as the order of events onData and onStateChanged is undetermined
     //(what a great decision...)
     //we need to postpone the data processing until either one or both have been fired
     clearDataTimer();
     m_dataId = setTimeout(function() { processData(m_data); m_data=null }, 0);
   }
   gICAPI.onData = function(data) {
     //alert("onData:"+data);
     mylog("onData:"+data);
     if (m_data) {
       myErr("gICAPI.onData: a previous dataset was pending:"+m_data+",data:"+data);
       processData(m_data); 
     }
     if (data===undefined || data===null) {
       alert("onData with undefined or null, check your code!!!");
       return;
     }
     m_data=data;
     scheduleProcessData();
   }
   processData = function(data) {
     clearDataTimer();
     mylog("processData:"+data+",m_updateOnData:"+m_updateOnData);
     if (data===null) {
       return; //state update
     }
     var o=JSON.parse(data);
     //mylog("onData m_state:"+m_state+",data:"+data);
     if (!o.vm) { //change was not issued by 4GL side ..GBC problem???
       mylog("!!!!!processData: o.vm not set:"+data);
       //checkUpdateOnData();
       return;
     } 
     if (o.cmdIdx<=m_cmdIdx) { //change was already sent, ignore
       mylog("o.cmdIdx:"+o.cmdIdx+" <= m_cmdIdx:"+m_cmdIdx);
       return;
     }
     m_cmdIdx = o.cmdIdx;
     if (o.flushTimeout!==undefined) {
       m_flushTimeout=o.flushTimeout;
     }
     m_dataPending=false; 
     if (o.extension!==undefined) {
       if (m_editor.EXTENSION!=o.extension) {
         mylog("extension changed from:"+m_editor.EXTENSION+" to:",o.extension);
         createEditor(o.extension);
       }
     }
     if (o.proparr!==undefined) {
       mylog("prepareCompletion");
       //alert("complete arr:"+data);
       m_proparr=o.proparr; //we preserve the completion list
       clearCompletionAliveTimer();
       m_completionId = setTimeout(function() {
           m_completionId = null;
           m_editor.showHint({hint: get4GLHint});
         },10);
     }
     //alert("data:"+data);
     if (o.full!==undefined) {
       if ((o.fileName!==undefined && o.fileName!=m_editor.FILENAME) ||
            o.cmCommand=="reload" ) {
         mylog("would swap doc");
         var doc=new CodeMirror.Doc(o.full,m_editor.getMode());
         m_editor.swapDoc(doc);
         m_editor.FILENAME=o.fileName;
         initLines(doc);
       } else if (o.full!==m_editor.getValue()) {
         setEditorValue(m_editor,o.full);
       }
     }
     if (o.cursor1!==undefined) {
       mylog("set cursor1:"+o.cursor1);
       if (o.cursor2===undefined) {
         o.cursor2=o.cursor1;
         mylog(" cursor2==cursor1:"+o.cursor1);
       } else {
         mylog(" cursor2:"+o.cursor2);
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
       findPersistent(m_editor);
     } else if (o.cmCommand=="replace") {
       doReplace(m_editor);
     }
     if (m_updateOnData===null && m_fglcm_init===false) {
       //initial roundtrip
       m_fglcm_init=true;
       myAction("fglcm_init");
     } else {
       checkUpdateOnData(o);
     }
     //m_editor.focus();
   }
   /*
   gICAPI.onFlushData = function() {
     clearUpdateTimer();
     if (m_updateOnData!==null) {
       mylog("onFlushData: m_updateOnData was:"+m_updateOnData);
       m_updateOnData=null;
     }
     mylog("onFlushData:m_InAction:"+m_InAction+",m_dataPending:"+m_dataPending);
     if (m_InAction || m_dataPending) {
       //we do not re send
       return;
     }
     var data=sync();
     gICAPI.SetData(data);
     mylog("onFlushData new data:"+data);
     //m_lastData=data;
  }*/

  gICAPI.onStateChanged=function(stateStr) {
    mylog("onStateChanged:"+stateStr);
    var stateObj = JSON.parse(stateStr);
    //var dialogType = stateObj.dialogType;
    var active = stateObj.active;
    m_active = active;
    setEditorEnabled(active);
    scheduleProcessData();
  }

  gICAPI.onProperty = function(p) { //do nothing as the trigger order is not reliable
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
    mylog("focus:"+e.tagName+",id:"+e.id+",className:"+e.className);
  }
}, 1000);
*/
//reset(m_editor);
