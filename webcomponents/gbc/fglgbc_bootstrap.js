/// FOURJS_START_COPYRIGHT(D,2018)
/// Property of Four Js*
/// (c) Copyright Four Js 2018, 2019. All Rights Reserved.
/// * Trademark of Four Js Development Tools Europe Ltd
///   in the United States and elsewhere
/// 
/// This file can be modified by licensees according to the
/// product manual.
/// FOURJS_END_COPYRIGHT

//modified bootstrapper to install our gICAPI as a middleware 
//between genero program and GBC webco

//"use strict";

(function() {
  var _gbc_loadTrials=0;
  var _urready=false;
  var _urreadySent=false;
  var _urreadyPending=false;
  var _lastidx=-1;

  function mylog(s) {
    console.log(s);
  }

  function sendURReady() {
    if (!_urready || _urreadyPending || _urreadySent || gICAPI.Action===undefined) {
      mylog("sendURReady() return _urready:"+_urready+",_urreadyPending:"+_urreadyPending+",_urreadySent:"+_urreadySent+",gICAPI.Action===undefined:"+gICAPI.Action===undefined);
      return;
    }
    _urreadyPending = true;
    setTimeout( function() {
      _urreadyPending = false;
      _urreadySent=true;
      mylog("send urready");
      gICAPI.Action("urready");
    },0);
  }

  try {
    gICAPI;
  } catch (e) {
    //wrappers for browser only test
    window.gICAPI={};
    gICAPI.Action=function(aName) {
      mylog(">>gICAPI.Action('"+aName+"')");
    }
    gICAPI.SetData=function(value) {
      mylog(">>gICAPI.SetData('"+value+"')");
    }
  }

  window.onICHostReady =function(version) { 
    sendURReady();
    gICAPI.onFocus=function(focusIn) {
      mylog("gICAPI.onFocus:"+focusIn);
    }
                                
    gICAPI.onData=function(data) {
      mylog("gICAPI.onData:"+data);
      if (!_urreadySent) {
        if (data.length>0) {
          alert("onData without _urreadySent:'"+data+"'");
        }
        return;
      }
      if (data.length==0) {
         mylog("data len is 0");
         return;
      }
      var bidx=data.indexOf("{");
      var sub=data.substring(3,bidx);
      var omIdx=parseInt(sub);
      mylog("omIdx:"+omIdx+",_lastidx:"+_lastidx);
      if (omIdx<=_lastidx) {
        console.log("idx didn't change,ignore command");
        return;
      }
      _lastidx=omIdx;
      window.gmiEmitReceive(data);
    }

    gICAPI.onProperty=function(p) { 
      mylog("gICAPI.onProperty:"+p);
    }
  }

  window.gbcWrapperInfo = {
    platformType: "native",
    platformName: "GDC",
    protocolType: "direct"
  };
  window.gmiErrorFile=function() {//indicates successful loading to GMI
    return "";
  }
  //called if GBC is up and running
  window.myReady=function() {
    var obj={nativeResourcePrefix:"___",
             meta:'meta Connection {{encoding "UTF-8"} {protocolVersion "102"} {interfaceVersion "110"} {runtimeVersion "3.20.03-2525"} {compression "none"} {encapsulation "1"} {filetransfer "1"} {procId "gonzo:123"} {rendering "universal"}}',
             forcedURfrontcalls:{},
             debugMode:1,
             logLevel:2};
    window.gmiEmitReady(obj);
  }
  window.gmiEmitReady=function(metaobj) {
    //first inject some missing API
    if (window.gbcWrapper==undefined) {
      alert("no gbcWrapper");
    }
    if (window.gbcWrapper.emit==undefined) {
      alert("no gbcWrapper");
    }
    window.sendFakeData = function() {
      //function to test the component without any VM side
      var fakedata='om 0 {{an 0 UserInterface 0 {{name "main"} {text "main"} {charLengthSemantics "0"} {procId "Leos-MacBook-Pro.local:8197"} {dbDate "MDY4/"} {dbCentury "R"} {decimalSeparator "."} {thousandsSeparator ","} {errorLine "-1"} {commentLine "-1"} {formLine "2"} {messageLine "1"} {menuLine "0"} {promptLine "0"} {inputWrap "0"} {fieldOrder "1"} {currentWindow "59"} {focus "57"} {runtimeStatus "interactive"}} {{ActionDefaultList 91 {{fileName "main.4ad"}} {}} {StyleList 60 {{fileName "main.4st"}} {}} {Window 59 {{name "screen"} {commentLine "-2"} {commentLineHidden "0"} {formLine "2"} {messageLine "1"} {menuLine "0"} {promptLine "0"} {errorLine "-1"} {posX "0"} {posY "0"} {width "80"} {height "25"} {style "main"}} {{Menu 58 {{text ""} {posY "0"} {active "1"} {selection "57"}} {{MenuAction 57 {{name "exit"} {text "exit"} {comment ""} {tabIndexRt "1"} {active "1"} {hidden "0"} {defaultView "yes"}} {}} {MenuAction 56 {{name "help"} {active "1"} {hidden "1"} {defaultView "yes"}} {}}}}}}}}}\n'
      var fakexata='om 0 {{an 0 UserInterface 0 {{name "main"} {text "main"} {charLengthSemantics "0"} {procId "Leos-MBP.homenet.telecomitalia.it:27130"} {dbDate "MDY4/"} {dbCentury "R"} {decimalSeparator "."} {thousandsSeparator ","} {errorLine "-1"} {commentLine "-1"} {formLine "2"} {messageLine "1"} {menuLine "0"} {promptLine "0"} {inputWrap "0"} {fieldOrder "1"} {currentWindow "109"} {focus "0"} {runtimeStatus "processing"}} {{ActionDefaultList 1 {{fileName "yy"}} {}} {StyleList 61 {{fileName "xx"}} {}} {Window 109 {{name "x"} {posX "0"} {posY "0"} {width "1"} {height "1"}} {{Form 110 {{name "test"} {build "3.20.03"} {width "1"} {height "1"} {formLine "2"}} {{Grid 111 {{width "1"} {height "1"}} {{Label 112 {{text "x"} {posY "0"} {posX "0"} {gridWidth "1"}} {}}}}}}}}}}}\n';
      console.log("send fake data");
      //window.gmiEmitReceive(fakedata);
      window.gmiEmitReceive(fakexata);
      //window.gbcWrapper.emit("receive", fakedata);
    }
    //called by GBC
    window.gbcWrapper.URReady = function(o) {
      console.log("URREADY:"+JSON.stringify(o));
      //window.webkit.messageHandlers.observeURReady.postMessage(o2);
      //setTimeout( window.sendFakeData, 0);
      _urready=true;
      sendURReady();
    }

    //called by GBC
    window.gbcWrapper.childStart = function() {
      console.log("[gURAPI debug] Call childStart()");
    }

    //called by GBC
    window.gbcWrapper.close = function() {
      console.log("[gURAPI debug] Call close()");
    }

    //called by GBC
    window.gbcWrapper.interrupt = function() {
      console.log("[gURAPI debug] Call interrupt()");
    }

    //called by GBC
    window.gbcWrapper.ping = function() {
      console.log("[gURAPI debug] Call ping()");
    }
   
    //called by GBC
    window.gbcWrapper.processing = function(isProcessing) {
      console.log("processing: "+isProcessing);
    }

    //called by GBC
    window.gbcWrapper.send = function(data) {
      console.log("!!!!!!!!!!!!!!!!!GBC calls send(" + data + ")");
    }
    
    //called by GBC
    window.gbcWrapper.frontcall = function(data, callback) {
      console.log("[gURAPI debug] frontcall(" + data + ") "+ callback);
      window._fc_callback=callback;
    };

    //called by GMI
    window.gmiFrontcallback = function(code) {
      var fc=window._fc_callback;
      window._fc_callback=null;
      //we just pass the status here,
      //the real result is sent to the VM if GBC returns to us
      var error=null;
      var result="somedummyresult";
      if (code==-2 || code==-3) {
        error="failed"
        result=null;
      }
      fc({status:code ,result:result, error:error});
    }

    //signal metaobj
    window.gbcWrapper.emit("ready", metaobj);
  }
  //called by us
  window.gmiEmitReceive=function(data) {
    //--console.log("!!!!!gmiEmitReceive: " + data);
    window.gbcWrapper.emit("receive", data);
  }
  //called by us
  window.gmiEmitDebugNode=function(nodeId) {
    //console.log("[gURAPI debug] debugNode: " + nodeId);
    window.gbcWrapper.emit("debugNode", nodeId);
  }
  //called by us
  window.gmiEmitAction=function(actionName) {
    //setTimeout( function() {
    //  console.log("[gURAPI debug] actionName: " + actionName);
    //  window.gbcWrapper.emit("nativeAction", { name: actionName });
    //}, 10);
    window.gbcWrapper.emit("nativeAction", { name: actionName });
  }
  function waitForGBCWrapper() {
    mylog("waitForGBCWrapper");
    var a=null;
    try {
      a=window.gbcWrapper.emit;
      myReady();
    } catch (msg) {
      _gbc_loadTrials++;
      console.log("_gbc_loadTrials:"+_gbc_loadTrials);
      if (_gbc_loadTrials>100) {
        //signal us that we can't get the wrapper
        gICAPI.Action("gbc_not_loaded");
      } else {
        setTimeout(waitForGBCWrapper,100);
      }
    }
  }
  waitForGBCWrapper();
})();
