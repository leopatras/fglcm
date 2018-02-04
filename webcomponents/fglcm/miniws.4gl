--mini webserver for testing a web component
--It's just listening on a random address and provides a testbed for
--the webcomponents initial page and it's assets
OPTIONS SHORT CIRCUIT
IMPORT com
IMPORT os
IMPORT util
DEFINE m_isMac INT

MAIN
  DEFINE i,idx,htport INT
  DEFINE pre,cliurl,url,page STRING
  DEFINE req com.HTTPServiceRequest
  DEFINE wcpre,fname,ext,ct STRING
  CALL util.Math.srand()
  LET m_isMac=NULL
  IF num_args()<1 THEN
    DISPLAY "usage: miniws <initial_page (relative path)>"
    EXIT PROGRAM 1
  END IF
  LET page=arg_val(1)
  IF (NOT os.Path.exists(page)) OR os.Path.isDirectory(page) THEN
    CALL myerr(sfmt("page %1 does not exist or is a directory",page))
  END IF
  --TODO: check if relative path
  LET htport=fgl_getenv("FGLAPPSERVER")
  IF htport IS NULL THEN
    LET htport = bindRandomPort()
    IF htport IS NULL THEN
      CALL myerr("can't find free port, please set FGLAPPSERVER")
    ELSE
      CALL fgl_setenv("FGLAPPSERVER",htport)
    END IF
  END IF
  --Frank, do I need this option?
  CALL com.WebServiceEngine.setOption("server_readwritetimeout",-1)
  CALL com.WebServiceEngine.Start()
  LET wcpre=sfmt("http://localhost:%1/",htport)
  LET cliurl = sfmt("%1%2?t=%3",wcpre,page,getCurrTimeStr()) --force browser reload
  --start browser... use some other commands on other os
  CALL openBrowser(cliurl)
  WHILE TRUE
  TRY
  LET req = com.WebServiceEngine.getHTTPServiceRequest(-1)
  CATCH
    DISPLAY "ERROR com.WebServiceEngine.getHTTPServiceRequest:",err_get(status)
    CONTINUE WHILE
  END TRY
  IF req IS NULL THEN
    DISPLAY "ERROR: getHTTPServiceRequest timed out (60 seconds). Exiting."
    EXIT WHILE
  ELSE
    LET url = req.getURL()
    DISPLAY "url:",url,",",req.getMethod()
    --FOR i=1 TO req.getRequestHeaderCount()
    --  DISPLAY sfmt("header %1:%2",req.getRequestHeaderName(i),req.getRequestHeaderValue(i))
    --END FOR
    CASE 
      WHEN url.getIndexOf(wcpre,1)==1 --wc asset 
        LET fname=url.subString(wcpre.getLength()+1,url.getLength())
        IF (idx:=fname.getIndexOf("?",1))<>0 THEN
          LET fname=fname.subString(1,idx-1)
        END IF
        LET fname=os.Path.join(os.Path.pwd(),fname)
        DISPLAY "fname:",fname
        IF os.Path.exists(fname) THEN
          LET ext=os.Path.extension(fname)
          LET ct=NULL
          CASE 
            WHEN ext=="html" OR ext=="css" OR ext=="js"
              CASE 
               WHEN ext=="html" LET ct="text/html"
               WHEN ext=="js"   LET ct="application/x-javascript"
               WHEN ext=="css"  LET ct="text/css"
                 CALL req.setResponseHeader("Content-Type", "text/css")
              END CASE
              IF ct IS NOT NULL THEN
                 CALL req.setResponseHeader("Content-Type", ct)
              END IF
              CALL req.setResponseCharset("UTF-8")
              CALL req.sendTextResponse(200,NULL,readTextFile(fname))
            OTHERWISE
              CASE 
                WHEN ext=="gif"  LET ct="image/gif"
                WHEN ext=="woff" LET ct="application/font-woff"
              END CASE
              IF ct IS NOT NULL THEN
                 CALL req.setResponseHeader("Content-Type", ct)
              END IF
              CALL req.sendDataResponse(200,NULL,readBlob(fname))
          END CASE 
        ELSE
          CALL req.sendTextResponse(404,NULL,sfmt("File:%1 not found",fname))
        END IF
    END CASE
  END IF
  END WHILE
END MAIN

FUNCTION readTextFile(fname)
  DEFINE fname,res STRING
  DEFINE t TEXT
  LOCATE t IN FILE fname
  LET res=t
  RETURN res
END FUNCTION

FUNCTION readBlob(fname)
  DEFINE fname STRING
  DEFINE blob BYTE
  LOCATE blob IN FILE fname
  RETURN blob
END FUNCTION

FUNCTION myerr(err)
  DEFINE err STRING
  DISPLAY "ERROR:",err
  EXIT PROGRAM 1
END FUNCTION

FUNCTION openBrowser(url)
  DEFINE url,cmd STRING
  DISPLAY "start GWC-JS URL:",url
  IF fgl_getenv("BROWSER") IS NOT NULL THEN
    LET cmd=sfmt("'%1' %2",fgl_getenv("BROWSER"),url)
  ELSE
    CASE
      WHEN isWin() 
        LET cmd=sfmt("start %1",url)
      WHEN isMac() 
        LET cmd=sfmt("open %1",url)
      OTHERWISE --assume kinda linux
        LET cmd=sfmt("xdg-open %1",url)
    END CASE
  END IF
  DISPLAY "browser cmd:",cmd
  RUN cmd WITHOUT WAITING
END FUNCTION

FUNCTION isWin()
  RETURN fgl_getenv("WINDIR") IS NOT NULL
END FUNCTION

FUNCTION isMac()
  IF m_isMac IS NULL THEN 
    LET m_isMac=isMacInt()
  END IF
  RETURN m_isMac
END FUNCTION

FUNCTION isMacInt()
  DEFINE arr DYNAMIC ARRAY OF STRING
  IF NOT isWin() THEN
    CALL file_get_output("uname",arr) 
    IF arr.getLength()<1 THEN 
      RETURN FALSE
    END IF
    IF arr[1]=="Darwin" THEN
      RETURN TRUE
    END IF
  END IF
  RETURN FALSE
END FUNCTION

FUNCTION file_get_output(program,arr)
  DEFINE program,linestr STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE mystatus,idx INTEGER
  DEFINE c base.Channel
  LET c = base.channel.create()
  WHENEVER ERROR CONTINUE
  CALL c.openpipe(program,"r")
  LET mystatus=status
  WHENEVER ERROR STOP
  IF mystatus THEN
    CALL myerr(sfmt("program:%1, error:%2",program,err_get(mystatus)))
  END IF
  CALL arr.clear()
  WHILE (linestr:=c.readline()) IS NOT NULL
    LET idx=idx+1
    --DISPLAY "LINE ",idx,"=",linestr
    LET arr[idx]=linestr
  END WHILE
  CALL c.close()
END FUNCTION

FUNCTION replace_char (str, chartofind , replacechar)
  DEFINE str,chartofind,replacechar STRING
  DEFINE idx INT
  WHILE (idx:=str.getIndexOf(chartofind,1))<>0
    LET str=str.subString(1,idx-1),replacechar,str.subString(idx+1,str.getLength())
  END WHILE
  RETURN str
END FUNCTION

FUNCTION replaceWSAndColonAndDot(str)
  DEFINE str STRING
  LET str=replace_char(str," ","_")
  LET str=replace_char(str,":","_")
  LET str=replace_char(str,".","_")
  RETURN str
END FUNCTION

FUNCTION getCurrTimeStr()
  DEFINE c STRING
  LET c= CURRENT
  RETURN replaceWSAndColonAndDot(c)
END FUNCTION

FUNCTION bindRandomPort()
  DEFINE ch base.Channel
  DEFINE port,i INT
  LET ch=base.Channel.create()
  FOR i=1 TO 10000
  TRY
    LET port=util.Math.rand(65535)
    IF port <= 1024 THEN --do not try reserved ports
      CONTINUE FOR
    END IF
    CALL ch.openServerSocket(NULL,port,"u")
    DISPLAY "bound port ok:",port
    CALL ch.close() --chance is high that we get this port
    RETURN port
  CATCH
    DISPLAY sfmt("can't bind port %1:%2",i,err_get(status))
  END TRY
  END FOR
  RETURN NULL
END FUNCTION
