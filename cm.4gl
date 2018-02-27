OPTIONS SHORT CIRCUIT
IMPORT util
IMPORT os
IMPORT FGL fgldialog
IMPORT FGL fglped_md_filedlg
IMPORT FGL fglped_fileutils
CONSTANT S_ERROR="Error"
--error image
CONSTANT IMG_ERROR="stop"
CONSTANT S_TYPE_CHANGED="typeChanged"
CONSTANT S_CLOSED="closed"

TYPE proparr_t DYNAMIC ARRAY OF STRING

--DEFINE cm STRING
DEFINE m_error_line STRING
DEFINE m_cline,m_ccol INT
DEFINE m_srcfile STRING
DEFINE m_title STRING
DEFINE compile_arr DYNAMIC ARRAY OF STRING
DEFINE m_CRCProg STRING
DEFINE m_CRCTable ARRAY[256] OF INTEGER
DEFINE m_lastCRC BIGINT
DEFINE m_modified BOOLEAN
DEFINE m_cmdIdx INT
DEFINE _on_mac STRING --cache the file_on_mac
CONSTANT HIGHBIT32=2147483648 -- == 0x80000000

DEFINE m_savedlines DYNAMIC ARRAY OF STRING

DEFINE m_orglines DYNAMIC ARRAY OF RECORD
    line STRING,
    orgnum INT
END RECORD

TYPE CmType RECORD
    modified DYNAMIC ARRAY OF RECORD
      orgnum INT,
      line STRING
    END RECORD,
    removed DYNAMIC ARRAY OF RECORD
      idx INT,
      len INT
    END RECORD,
    inserts DYNAMIC ARRAY OF RECORD
      orgnum INT,
      ilines DYNAMIC ARRAY OF RECORD
        line STRING,
        orgnum INT
      END RECORD
    END RECORD,
    full STRING, --only used for debugging
    crc BIGINT,
    len INT,
    lineCount INT,
    cursor1 RECORD
      line INT,
      ch INT
    END RECORD,
    cursor2 RECORD
      line INT,
      ch INT
    END RECORD,
    proparr proparr_t,
    vm BOOLEAN,  --we set this to true whenever 4GL wants to change values
    cmdIdx INT, --force reload
    extension STRING, --extension of or source file
    annotations DYNAMIC ARRAY OF RECORD --pass errors and warnings
      from RECORD 
        line INT,
        ch INT
      END RECORD,
      to RECORD
        line INT,
        ch INT
      END RECORD,
      message STRING,
      severity STRING
    END RECORD
END RECORD

DEFINE m_cmRec CmType
DEFINE m_cm STRING

MAIN
  DEFINE dummy INT
  CALL initCRC32Table()
  LET m_lastCRC=NULL
  LET m_CRCProg=os.Path.fullPath(os.Path.join(os.Path.dirname(arg_val(0)),"crc32"))
  DISPLAY "m_CRCProg:",m_CRCProg
  IF NOT os.Path.exists(m_CRCProg) OR NOT os.Path.executable(m_CRCProg) THEN
    LET m_CRCProg=NULL
  END IF
  CALL edit_source(arg_val(1)) RETURNING dummy
END MAIN

--main INPUT to edit the form, everything is called from here
FUNCTION edit_source(fname)
  DEFINE fname STRING
  DEFINE proparr proparr_t
  DEFINE changed INTEGER
  DEFINE jump_to_error BOOLEAN
  DEFINE tmpname,ans,result,cname,saveasfile,dummy STRING
  --IF ui.Window.forName("screen") IS NULL THEN
  --  OPEN WINDOW screen WITH FORM "cm"
  --ELSE
    OPEN FORM f FROM "cm"
    DISPLAY FORM f
  --END IF
  LET changed=1
  IF fname IS NULL THEN
    LET m_srcfile=NULL
    CALL file_new()
  ELSE
    LET m_srcfile=fname
    IF NOT file_read(m_srcfile) THEN
      IF (ans:=fgl_winquestion("fglped",sfmt("The file \"%1\" cannot be found, create new?",m_srcfile),"yes","yes|no|cancel","question",0))="cancel" THEN
        RETURN 1
      END IF
      CALL file_new()
      IF ans="yes" THEN
        IF NOT my_write(m_srcfile) THEN
          EXIT PROGRAM 1
        END IF
      ELSE
        EXIT PROGRAM 1
      END IF
    END IF
  END IF
  LET tmpname=setCurrFile(m_srcfile,tmpname)
  CALL savelines()
  CALL initialize_when(TRUE)
  CALL compileTmp(tmpname,TRUE)
  CALL display_full(FALSE,FALSE)
  CALL flush_cm()
  OPTIONS INPUT WRAP
  INPUT m_cm WITHOUT DEFAULTS FROM cm ATTRIBUTE(accept=FALSE,cancel=FALSE)
    ON ACTION close
      CALL fcsync()
      IF checkFileSave()="cancel" THEN
        CONTINUE INPUT
      ELSE
        EXIT INPUT
      END IF
    ON ACTION complete
      --LET src=update() 
      CALL sync() 
      IF NOT my_write(tmpname) THEN
        EXIT INPUT
      END IF
      INITIALIZE m_cmRec.* TO NULL
      LET m_cmRec.proparr=complete(tmpname)
      CALL compile_and_process(tmpname,FALSE) RETURNING dummy
      CALL flush_cm()
    ON ACTION gotoline
      CALL fcsync()
      CALL do_gotoline()
    ON ACTION update
      CALL sync()
      LET jump_to_error=FALSE
      GOTO do_compile
    ON ACTION compile
      --LET src=update() 
      CALL fcsync()
      LET jump_to_error=TRUE
LABEL do_compile:
      CALL initialize_when(TRUE)
      CALL compileTmp(tmpname,jump_to_error)
      CALL flush_cm()
    ON ACTION new
      CALL fcsync()
      IF (ans:=checkFileSave())="cancel" THEN CONTINUE INPUT END IF
      CALL file_new()
      CALL display_full(TRUE,TRUE)
      LET tmpname=setCurrFile("",tmpname)
    ON ACTION open
      --LET src = update()
      CALL fcsync()
      IF (ans:=checkFileSave())="cancel" THEN CONTINUE INPUT END IF
      CALL initialize_when(TRUE)
      IF ans="no" THEN 
        --LET src=src_copy 
        CALL restorelines()
        CALL display_full(FALSE,FALSE)
      END IF
      --LET src_copy = src
      CALL savelines()
      --LET m_infiledlg=1
      LET cname = fglped_filedlg()
      --LET m_infiledlg=0
--LABEL doOpen:
      IF cname IS NOT NULL THEN
        IF NOT file_read(cname) THEN
          --LET src=src_copy
          CALL restorelines()
          CALL fgl_winmessage(S_ERROR,sfmt("Can't read:%1",cname),IMG_ERROR)
        ELSE
          --LET src_copy = src
          CALL savelines()
          LET tmpname = setCurrFile(cname,tmpname)
          CALL display_full(FALSE,FALSE)
          --CALL close_sc_window()
          --GOTO dopreview
        END IF
      ELSE
        --LET src = open_copy
        --CALL display_full()
      END IF
      CALL flush_cm()
    ON ACTION sync
      CALL sync()
    ON ACTION save
      DISPLAY "save"
      CALL fcsync()
      IF isNewFile() THEN
        GOTO dosaveas
      END IF
      --LET src=update()
      IF NOT file_write(m_srcfile) THEN
        CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",m_srcfile),IMG_ERROR)
      ELSE
        MESSAGE "saved:",m_srcfile
        CALL savelines()
      END IF
    ON ACTION saveas
      DISPLAY "saveas"
LABEL dosaveas:
      IF (saveasfile:=fglped_saveasdlg(m_srcfile)) IS NOT NULL THEN
        IF NOT file_write(saveasfile) THEN
          CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",saveasfile),IMG_ERROR)
        ELSE
          LET tmpname=setCurrFile(saveasfile,tmpname)
          --LET src_copy=src
          CALL savelines()
          CALL mysetTitle()
          CALL display_full(TRUE,TRUE)
        END IF
      END IF
  END INPUT
  CALL delete_tmpfiles(tmpname) 
  --CALL close_sc_window()
  RETURN 0
END FUNCTION

FUNCTION is4GLOrPer(fname)
  DEFINE fname STRING
  RETURN os.Path.extension(fname)=="4gl" OR os.Path.extension(fname)=="per" 
END FUNCTION

FUNCTION compileTmp(tmpname,jump_to_error)
  DEFINE tmpname,compmess STRING
  DEFINE jump_to_error BOOLEAN
  IF is4GLORPer(tmpname) THEN
    LET compmess = saveAndCompile(tmpname,jump_to_error)
    IF compmess IS NULL THEN
      CALL mymessage("Compile ok")
    END IF
  END IF
END FUNCTION

FUNCTION mymessage(msg)
  DEFINE msg STRING
  IF ui.Interface.getFrontEndName()=="GBC" THEN
    --TODO
    --the message block overlaps the editor with larger messages
    RETURN
  END IF
  MESSAGE msg
END FUNCTION

FUNCTION update()
  DEFINE newVal,cm STRING
  DEFINE cmRec CmType
  --LET newVal=fgl_dialog_getbuffer()
  CALL ui.Interface.frontCall("webcomponent","call",["formonly.cm","getData"],[newVal])
  CALL util.JSON.parse(newVal,cmRec)
  DISPLAY "cm:",util.JSON.stringify(cmRec)
  DISPLAY "----"
  LET m_cline=cmRec.cursor1.line+1
  LET m_ccol=cmRec.cursor1.ch+1
  DISPLAY cmRec.full
  DISPLAY "----"
  --LET cm=newVal
END FUNCTION

FUNCTION fcsync()
  DEFINE newVal STRING
  CALL ui.Interface.frontCall("webcomponent","call",["formonly.cm","fcsync"],[newVal])
  CALL syncInt(newVal)
END FUNCTION

FUNCTION sync() --called if the webco fired an action
  CALL syncInt(fgl_dialog_getbuffer())
END FUNCTION

FUNCTION syncInt(newVal)
  DEFINE newVal,line,src STRING
  DEFINE orgnum,idx,i,j,z,len,insertpos INT
  DEFINE crc BIGINT
  DEFINE cmRec CmType
  DISPLAY "newVal:",newVal
  IF newVal IS NULL THEN
    DISPLAY "!!!NULL!!!"
    CALL fgl_winmessage("Error","syncInt was called with NULL","error")
    RETURN 
  END IF
  CALL util.JSON.parse(newVal,cmRec)
  DISPLAY "cm:",util.JSON.stringify(cmRec)
  DISPLAY ">>----"
  --LET src=cmRec.full
  LET m_cline=cmRec.cursor1.line+1
  LET m_ccol=cmRec.cursor1.ch+1
  LET len=cmRec.modified.getLength()
  FOR i=1 TO len
    LET orgnum=cmRec.modified[i].orgnum+1
    IF orgnum>=1 AND orgnum<=m_orglines.getLength() THEN
      LET line=cmRec.modified[i].line
      IF checkChanged(line,m_orglines[orgnum].line) THEN
        DISPLAY sfmt("patch line:%1 from:'%2' to:'%3'",orgnum,m_orglines[orgnum].line,line)
        CALL setModified()
        LET m_orglines[orgnum].line=line
      END IF
    ELSE
      DISPLAY sfmt("index out of range:%1 m_orglines.getLength():%2",orgnum,m_orglines.getLength())
    END IF
  END FOR
  IF cmRec.removed.getLength()>0 THEN
    CALL setModified()
  END IF
  FOR i=cmRec.removed.getLength() TO 1 STEP -1
    LET m_modified=TRUE
    LET idx=cmRec.removed[i].idx+1
    LET len=cmRec.removed[i].len
    DISPLAY sfmt("delete lines:%1-%2",idx,idx+len-1)
    FOR j=1 TO len
      --DISPLAY "delete line:'",m_orglines[idx].line,"'"
      CALL m_orglines.deleteElement(idx)
    END FOR
  END FOR
  IF cmRec.inserts.getLength()>0 THEN
    CALL setModified()
  END IF
  LET j=1
  FOR i=1 TO cmRec.inserts.getLength()
    LET m_modified=TRUE
    LET orgnum=cmRec.inserts[i].orgnum+1
    WHILE j<=m_orglines.getLength()
      IF m_orglines[j].orgnum==orgnum THEN
        LET len=cmRec.inserts[i].ilines.getLength()
        --DISPLAY sfmt("insert %1 new lines at:%2",len,j+1)
        FOR z=1 TO len
          LET insertpos=j+z
          CALL m_orglines.insertElement(insertpos)
          LET m_orglines[insertpos].line=cmRec.inserts[i].ilines[z].line
          LET m_orglines[insertpos].orgnum=-1
        END FOR
        EXIT WHILE
      END IF
      LET j=j+1
    END WHILE
  END FOR
  LET m_lastCRC=cmRec.crc
  DISPLAY sfmt("len:%1, lineCount:%2,crc:",cmRec.len,cmRec.lineCount,m_cmRec.crc)
  IF m_orglines.getLength()<>cmRec.lineCount THEN
    CALL err(SFMT("linecount local %1 != linecount remote %2",m_orglines.getLength(),cmRec.lineCount))
  END IF
  {
  LET src=arr2String()
  LET crc=crc32(src)
  IF crc<>cmRec.crc THEN
    --IF src.getLength()<>cmRec.full.getLength() THEN
    --DISPLAY sfmt("full len %1 != computed getLength %2",cmRec.full.getLength(),src.getLength())
    CALL fgl_winmessage("Error",sfmt("CRC local %1 != CRC codemirror %2",crc,cmRec.crc),"error")
    DISPLAY sfmt("crc local %1 != crc codemirror %2",crc,cmRec.crc)
  ELSE
    --IF src<>cmRec.full THEN
    --  DISPLAY "src!=full"
    --ELSE
    DISPLAY "ok!!! src==full"
    --END IF
  END IF
  --DISPLAY src
  }
  DISPLAY ">>----"
  --renumber and compute character count
  LET len=0
  FOR i=m_orglines.getLength() TO 1 STEP -1
    LET line=m_orglines[i].line
    LET len=len+line.getLength()
    IF i<>0 THEN
      LET len=len+1 --newline
    END IF
    LET m_orglines[i].orgnum=i
  END FOR
  IF len<>m_cmRec.len THEN
    CALL err(SFMT("character count local %1 != character count remote %2",len,cmRec.len))
  END IF
END FUNCTION

FUNCTION flush_cm()
  LET m_cmdIdx=m_cmdIdx+1
  LET m_cmRec.cmdIdx=m_cmdIdx
  LET m_cmRec.vm=TRUE
  LET m_cm=util.JSON.stringifyOmitNulls(m_cmRec)
  IF m_cm.getLength()>140 THEN
    DISPLAY sfmt("flush:%1...%2",m_cm.subString(1,70),m_cm.subString(m_cm.getLength()-60,m_cm.getLength()))
  ELSE 
    DISPLAY "flush:",m_cm
  END IF
  --CALL fgl_dialog_setbuffer(m_cm)
  DISPLAY m_cm TO cm
END FUNCTION

FUNCTION do_gotoline()
  DEFINE lineno INT
  LET lineno=1
  OPEN WINDOW gotoline WITH FORM "fglcm_gotoline"
  LET int_flag=FALSE
  INPUT BY NAME lineno WITHOUT DEFAULTS
  CLOSE WINDOW gotoline
  IF NOT int_flag THEN
    CALL jump_to_line(lineno,1,lineno,1,TRUE,TRUE)
  END IF
END FUNCTION

FUNCTION initialize_when(initialize)
  DEFINE initialize BOOLEAN
  IF initialize THEN
    DISPLAY "initialize m_cmRec"
    INITIALIZE m_cmRec.* TO NULL
  END IF
END FUNCTION

FUNCTION flush_when(flush)
  DEFINE flush BOOLEAN
  IF flush THEN
    CALL flush_cm()
  END IF
END FUNCTION
   
--line and character numbers in codemirror start with 0
FUNCTION line2cm(line)
  DEFINE line INT
  RETURN line-1
END FUNCTION

FUNCTION jump_to_line(linenum,col,line2,col2,initialize,flush)
  DEFINE linenum,col,line2,col2 INT
  DEFINE initialize,flush BOOLEAN
  DEFINE cm STRING
  CALL initialize_when(initialize)
  LET m_cmRec.cursor1.line=line2cm(linenum)
  LET m_cmRec.cursor1.ch=line2cm(col)
  LET m_cmRec.cursor2.line=line2cm(line2)
  LET m_cmRec.cursor2.ch=IIF(linenum==line2 AND col==col2,line2cm(col),col2)
  CALL flush_when(flush)
END FUNCTION

FUNCTION display_full(initialize,flush)
  DEFINE initialize,flush BOOLEAN
  DEFINE ext,basename STRING
  CALL initialize_when(initialize)
  LET m_cmRec.full=arr2String()
  LET ext=os.Path.extension(m_srcfile)
  LET basename=os.Path.baseName(m_srcfile)
  DISPLAY "display_full:",m_srcfile,",ext:",ext,",basename:",basename
  CASE 
    WHEN ext.getLength()>0 
      LET m_cmRec.extension=ext
    WHEN basename.toLowerCase()=="makefile"
      LET m_cmRec.extension="makefile"
  END CASE
  CALL flush_when(flush)
END FUNCTION

FUNCTION compile_and_process(fname,jump_to_error)
  DEFINE fname STRING
  DEFINE jump_to_error BOOLEAN
  DEFINE compmess STRING
  LET compmess=compile_source(fname,0)
  IF compmess IS NOT NULL THEN
    CALL process_compile_errors(jump_to_error)
  END IF
  RETURN compmess
END FUNCTION

FUNCTION saveAndCompile(fname,jump_to_error)
  DEFINE fname STRING
  DEFINE jump_to_error BOOLEAN
  DEFINE compmess STRING
  IF file_write(fname) THEN
    LET compmess=compile_and_process(fname,jump_to_error)
  ELSE 
    LET m_error_line=sfmt("Can't write to:%1",fname)
    CALL fgl_winmessage(S_ERROR,m_error_line,IMG_ERROR)
  END IF
  RETURN compmess
END FUNCTION

FUNCTION compile_source(fname,proposals)
  DEFINE fname STRING
  DEFINE showmessage INT
  DEFINE proposals INT
  DEFINE dirname,cmd,mess,cparam,firstErrLine,line,srcname,compOrForm STRING
  DEFINE code,i,atidx INT
  DEFINE isPER BOOLEAN
  LET dirname=file_get_dirname(fname)
  LET isPER=os.Path.extension(fname)=="per"
  IF isPER THEN
    LET cparam="-c"
  END IF
  IF proposals THEN
    LET cparam="-L"
  END IF
  IF isPER OR proposals THEN
    LET cparam=sfmt("%1 %2,%3",cparam,m_cline,m_ccol)
  ELSE
    LET cparam=""
  END IF
  LET compOrForm=IIF(isPER,"fglform","fglcomp")
  IF file_on_windows() THEN
    LET cmd=sfmt("set FGLDBPATH=%1;%%FGLDBPATH%% && %2 %3 -M %4 2>&1",dirname,compOrForm,cparam,fname)
  ELSE
    LET cmd=sfmt("export FGLDBPATH=\"%1\":$FGLDBPATH && %2 %3 -M \"%4\" 2>&1",dirname,compOrForm,cparam,fname)
  END IF
  CALL compile_arr.clear()
  --DISPLAY "cmd=",cmd
  IF proposals THEN
    --DISPLAY "cmd=",cmd
  END IF
  IF NOT proposals THEN
    RUN cmd RETURNING code 
  END IF
  IF code OR proposals THEN
    CALL file_get_output(cmd,compile_arr)
    IF (atidx:=fname.getIndexOf(".@",1))>0 THEN
      LET srcname=fname.subString(1,atidx-1),fname.subString(atidx+2,fname.getLength())
    ELSE
      LET srcname=fname
    END IF
    LET mess="compiling of '",srcname,"' failed:\n"
    FOR i=1 TO compile_arr.getLength()
      LET line=compile_arr[i]
      IF (atidx:=line.getIndexOf(".@",1))>0 THEN
        LET compile_arr[i]=line.subString(1,atidx-1),line.subString(atidx+2,line.getLength())
      END IF
      IF i=1 THEN
        LET firstErrLine=compile_arr[i]
      END IF
      LET mess=mess,compile_arr[i],"\n"
    END FOR
    RETURN mess
  END IF
  RETURN ""
END FUNCTION

--calls the form compiler in completion mode
--and makes some computations to present a display array with possible
--completion tokens
FUNCTION complete(fname)
  DEFINE fname STRING
  DEFINE compmess STRING
  DEFINE proposal STRING
  DEFINE proparr proparr_t
  DEFINE tok base.StringTokenizer
  DEFINE i,j,len INT
  DEFINE sub STRING
  LET compmess=compile_source(fname,1)
  FOR i=1 TO compile_arr.getLength()
    LET proposal=compile_arr[i]
    IF proposal.getIndexOf("proposal",1)=1 THEN
      CALL proparr.appendElement()
      LET len=proparr.getLength()
      LET tok=base.StringTokenizer.create(proposal,"\t")
      LET j=1
      WHILE tok.hasMoreTokens() 
        LET sub=tok.nextToken()
        CASE j
          WHEN 2
            LET proparr[len]=sub
            LET proposal=sub
          WHEN 3
            --LET proparr[len].kind=sub
        END CASE
        LET j=j+1
      END WHILE
      --eliminite duplicates
      LET len=len-1
      FOR j=1 TO len
        IF proparr[j]=proposal THEN
          --DISPLAY "!!remove duplicate:",proposal
          CALL proparr.deleteElement(len+1)
          EXIT FOR
        END IF
      END FOR
    END IF
  END FOR
  RETURN proparr
END FUNCTION


FUNCTION err(errstr)
  DEFINE errstr STRING
  CALL fgl_winMessage("Error",errstr,"error")
  DISPLAY "ERROR:",errstr
  EXIT PROGRAM 1
END FUNCTION

FUNCTION setModified() 
  IF NOT m_modified THEN
    DISPLAY "setModified() TRUE"
    LET m_modified=TRUE
  END IF
END FUNCTION

FUNCTION checkChangedArray()
  DEFINE savelen,len,i INT
  IF m_modified=FALSE THEN
    DISPLAY "checkChangedArray() no mod"
    RETURN FALSE
  END IF
  LET savelen=m_savedlines.getLength()
  LET len=m_orglines.getLength()
  IF savelen<>len THEN
    DISPLAY SFMT("savelen:%1 len:%2",savelen,len)
    RETURN TRUE
  END IF
  FOR i=1 TO len
    IF checkChanged(m_savedlines[i],m_orglines[i].line) THEN
      DISPLAY sfmt("line:%1 differs '%2'<>'%3'",i,m_savedlines[i],m_orglines[i].line)
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

--the usual 4GL function  to check if 2 strings are different
FUNCTION checkChanged(src,copy2)
  DEFINE src STRING
  DEFINE copy2 STRING
  IF ( copy2 IS NOT NULL  AND src IS NULL     ) OR 
     ( copy2 IS NULL      AND src IS NOT NULL ) OR 
     ( copy2<>src ) OR ( copy2.getLength()<>src.getLength() ) THEN
     RETURN 1
  END IF
  RETURN 0
END FUNCTION

FUNCTION my_write(fname)
  DEFINE fname STRING
  IF NOT file_write(fname) THEN
    CALL fgl_winmessage(S_ERROR,sfmt("Can't write to:%1",fname),IMG_ERROR)
    RETURN FALSE
  END IF
  DISPLAY "did write to:",fname
  RETURN TRUE
END FUNCTION


--collects the errors and jumps to the first one optionally
FUNCTION process_compile_errors(jump_to_error)
  DEFINE jump_to_error INT
  DEFINE idx,erridx INT
  DEFINE first BOOLEAN
  DEFINE firstcolon,secondcolon,thirdcolon,fourthcolon,fifthcolon,linenum,c,start INT
  DEFINE line,col,col2,linenumstr,line2numstr STRING
  LET idx=1
  LET m_error_line=""
  IF idx>compile_arr.getLength() OR idx<1 THEN
    RETURN 
  END IF
  WHILE idx<=compile_arr.getLength() AND idx>0 
    LET line=compile_arr[idx]
    LET start=1
    IF (firstcolon:=line.getIndexOf(":",1))>0 AND firstcolon=2 AND
        line.getCharAt(3)="\\" THEN
      --exclude drive letters under windows
      LET start=3
    END IF
    IF (firstcolon:=line.getIndexOf(":",start))>0 AND line.getIndexOf(":error:",1)<>0 THEN
      LET secondcolon=line.getIndexOf(":",firstcolon+1)
      LET thirdcolon=line.getIndexOf(":",secondcolon+1)
      LET fourthcolon=line.getIndexOf(":",thirdcolon+1)
      LET fifthcolon=line.getIndexOf(":",fourthcolon+1)
      IF secondcolon>firstcolon THEN
        LET linenumstr=line.subString(firstcolon+1,secondcolon-1)
        LET col=line.subString(secondcolon+1,thirdcolon-1)
        LET line2numstr=line.subString(thirdcolon+1,fourthcolon-1)
        LET col2=line.subString(fourthcolon+1,fifthcolon-1)
        LET linenum=linenumstr
        IF linenum>0 OR (linenumstr="0" AND 
                         line.getIndexOf("expecting",1)<>0) THEN
          LET line=line.subString(firstcolon,line.getLength())
          LET m_error_line=line
          IF NOT first THEN
            LET first=TRUE
            CALL mymessage(m_error_line)
          END IF
          --ERROR m_error_line
          IF linenumstr="0" THEN 
            LET linenum=1
          END IF
          LET erridx=m_cmRec.annotations.getLength()+1
          LET m_cmRec.annotations[erridx].from.line=line2cm(linenum)
          LET m_cmRec.annotations[erridx].from.ch=line2cm(col)
          LET m_cmRec.annotations[erridx].to.line=line2cm(line2numstr)
          LET m_cmRec.annotations[erridx].to.ch=col2
          LET m_cmRec.annotations[erridx].message=m_error_line
          LET m_cmRec.annotations[erridx].severity="error"
          IF jump_to_error THEN
            CALL jump_to_line(linenum,col,line2numstr,col2,FALSE,FALSE)
            LET jump_to_error=FALSE
          END IF
        END IF
      END IF
      --EXIT WHILE
    END IF
    LET idx=idx+1
  END WHILE
END FUNCTION

FUNCTION file_read(srcfile)
  DEFINE srcfile STRING
  DEFINE ch base.Channel
  DEFINE line STRING
  DEFINE linenum INT
  LET  ch=base.channel.create()
  CALL m_orglines.clear()
  TRY
  CALL ch.openFile(srcfile,"r")
  LET linenum=1
  IF status == 0 THEN
    WHILE NOT ch.isEof()
      LET line=ch.readLine()
      IF ch.isEof() THEN
        --we always have at least one line allocated
        IF line.getLength()==0 AND linenum>1 THEN
          EXIT WHILE
        END IF
      END IF
      LET m_orglines[linenum].line=line
      LET m_orglines[linenum].orgnum=linenum
      LET linenum=linenum+1
    END WHILE
    CALL ch.close()
  END IF
  --DISPLAY "m_orglines:",util.JSON.stringify(m_orglines),",len:",m_orglines.getLength()
  CATCH
    DISPLAY err_get(status)
    RETURN FALSE
  END TRY
  RETURN TRUE
END FUNCTION

FUNCTION arr2String()
  DEFINE buf base.StringBuffer
  DEFINE result STRING
  DEFINE len,i INT
  LET buf=base.StringBuffer.create()
  LET len=m_orglines.getLength()
  FOR i=1 TO len
    CALL buf.append(m_orglines[i].line)
    IF i<>len THEN
      CALL buf.append("\n")
    END IF
  END FOR
  LET result=buf.toString()
  IF result IS NULL THEN
    LET result=" " CLIPPED
  END IF
  RETURN result
END FUNCTION

--gives back the directory portion of a filename
FUNCTION file_get_dirname(filename)
  DEFINE filename STRING
  DEFINE dirname STRING
  LET dirname=os.Path.dirname(filename)
  IF dirname IS NULL THEN
    LET dirname="."
  END IF
  RETURN dirname
END FUNCTION

FUNCTION file_write_int(srcfile,mode)
  DEFINE srcfile STRING
  DEFINE mode STRING
  DEFINE ch base.Channel
  DEFINE result,mystatus INT
  DEFINE idx,old,len INT
  DEFINE line STRING
  LET  ch=base.channel.create()
  CALL ch.setDelimiter("")
  WHENEVER ERROR CONTINUE
  CALL ch.openFile(srcfile,mode)
  --CALL ch.setDelimiter("")
  LET mystatus=status
  WHENEVER ERROR stop
  IF mystatus <> 0 THEN
    LET result=0
  ELSE
    LET len=m_orglines.getLength()
    FOR idx=1 TO len
      IF idx<>len THEN
        --DISPLAY sfmt("writeLine %1 '%2'",idx,m_orglines[idx].line)
        CALL ch.writeLine(m_orglines[idx].line)
      ELSE
        LET line=m_orglines[idx].line
        --DISPLAY sfmt("write last line %1 '%2'",idx,line)
        CALL ch.writeNoNL(line)
      END IF
    END FOR
    LET result=TRUE
    CALL ch.close()
  END IF
  RETURN result
END FUNCTION

FUNCTION file_write(srcfile)
  DEFINE srcfile STRING
  DEFINE start,t DATETIME YEAR TO FRACTION(2)
  DEFINE result INT
  LET start=CURRENT
  LET result=file_write_int(srcfile,"w")
  DISPLAY "time for file_write:",CURRENT-start
  IF m_lastCRC IS NOT NULL AND 
      ( m_CRCProg IS NOT NULL OR file_on_mac() ) THEN
    LET start=CURRENT
    CALL checkCRCSum(srcfile)
    DISPLAY "time for cksum:",CURRENT-start,",crc32:",m_cmRec.crc
  END IF
  RETURN result
END FUNCTION

FUNCTION checkCRCSum(fname)
  DEFINE fname,s,cmd STRING
  DEFINE tok base.StringTokenizer
  DEFINE first BIGINT
  IF m_CRCProg IS NOT NULL  THEN
    LET cmd=sfmt("%1 %2",m_CRCProg,fname)
  ELSE --only mac
    LET cmd=sfmt("cksum -o 3 %1",fname)
  END IF
  LET s=file_get_output_string(cmd)
  DISPLAY sfmt("%1 returned:%2",cmd,s)
  LET tok=base.StringTokenizer.create(s," ")
  LET first=tok.nextToken()
  IF first<>m_lastCRC THEN
    CALL err(sfmt("crc cksum %1 != crc codemirror %2",first,m_lastCRC))
  END IF
  LET m_lastCRC=NULL
END FUNCTION

FUNCTION file_on_windows()
  IF fgl_getenv("WINDIR") IS NULL THEN
    RETURN 0
  ELSE
    RETURN 1
  END IF
END FUNCTION

FUNCTION _file_uname()
  DEFINE dummy INT
  DEFINE arr DYNAMIC ARRAY OF STRING
  IF file_on_windows() THEN RETURN "Windows" END IF
  CALL file_get_output("uname",arr)
  IF arr.getLength()<1 THEN 
    RETURN "Unknown"
  END IF
  RETURN arr[1]
END FUNCTION

FUNCTION file_on_mac()
  IF _on_mac is NULL THEN
    LET _on_mac=( _file_uname()=="Darwin" )
  END IF
  RETURN _on_mac=="1"
END FUNCTION


FUNCTION cut_extension(pname)
  DEFINE pname STRING
  DEFINE basename,ext STRING
  LET basename=pname
  LET ext=os.Path.extension(pname)
  IF ext IS NOT NULL THEN
    LET basename=pname.subString(1,pname-ext.getLength()+1)
  END IF
  RETURN basename
END FUNCTION

FUNCTION checkFileSave()
  DEFINE ans STRING
  DEFINE dummy INT
  IF checkChangedArray() THEN
    IF (ans:=fgl_winquestion("fglped",sfmt("Save changes to %1?",m_title),"yes","yes|no|cancel","question",0))="yes" THEN
      IF isNewFile() THEN
        LET m_srcfile=fglped_saveasdlg(m_srcfile)
        IF m_srcfile IS NULL THEN
          RETURN "cancel"
        END IF
      END IF
      CALL my_write(m_srcfile) RETURNING dummy
    END IF
  END IF
  RETURN ans
END FUNCTION

FUNCTION file_new()
  CALL m_orglines.clear()
  LET m_orglines[1].line=" " CLIPPED
  LET m_orglines[1].orgnum=1
  CALL savelines()
END FUNCTION

FUNCTION setCurrFile(fname,tmpname) --sets m_srcfile
  DEFINE fname,tmpname STRING
  LET m_srcfile=fname
  CALL delete_tmpfiles(tmpname)
  LET tmpname = getTmpFileName(m_srcfile)
  CALL mysetTitle()
  RETURN tmpname
END FUNCTION

--computes the temporary .per file name to work with during our manipulations
FUNCTION getTmpFileName(fname)
  DEFINE fname STRING
  DEFINE tmpname STRING
  DEFINE dir,shortname STRING
  DEFINE ext STRING
  LET ext=os.Path.extension(fname)
  IF fname IS NULL THEN
    --LET tmpname=".@__empty__.",ext
    LET tmpname=".@__empty__.4gl"
  ELSE
    LET dir=file_get_dirname(fname)
    LET shortname=os.Path.basename(fname)
    LET tmpname=os.Path.join(dir,sfmt(".@%1",shortname))
    --LET tmpname=cut_extension(tmpname),ext
  END IF
  RETURN tmpname
END FUNCTION

--returns true if the current contents was initialized by File->New
--or File->New From Wizard
FUNCTION isNewFile()
  IF m_srcfile IS NULL 
    --OR os.Path.baseName(m_srcfile)=WIZGEN 
    THEN
    RETURN 1
  END IF
  RETURN 0
END FUNCTION

FUNCTION delete_tmpfiles(tmpname)
  DEFINE tmpname STRING
  DEFINE dummy INT
  IF tmpname IS NULL THEN
    RETURN
  END IF
  CALL os.Path.delete(tmpname) RETURNING dummy
  CASE os.Path.extension(tmpname)
  WHEN "per"
    CALL os.Path.delete(cut_extension(tmpname)||".42f") RETURNING dummy
  WHEN "4gl"
    CALL os.Path.delete(cut_extension(tmpname)||".42m") RETURNING dummy
  END CASE
END FUNCTION

FUNCTION mysetTitle()
  IF isNewFile() THEN
    LET m_title="Unnamed"
  ELSE
    LET m_title=os.Path.baseName(m_srcfile)
  END IF
  CALL fgl_setTitle(sfmt("%1 - fglped",m_title))
END FUNCTION

FUNCTION fglped_saveasdlg(fname)
  DEFINE fname STRING
  DEFINE filename STRING
  --CALL fgl_winmessage("Info",sfmt("fglped_saveasdlg %1",fname),"info")
  IF fname IS NULL THEN
    LET fname=os.Path.pwd()
  END IF
  CALL ui.Interface.frontCall("standard","saveFile", [fname, "All Files", "*.*", "Save File" ], [filename])
  DISPLAY "filename:",filename
  RETURN filename
END FUNCTION

{
FUNCTION fglped_filedlg()
  DEFINE filename STRING
  CALL ui.Interface.frontCall("standard","openfile", [os.Path.pwd(), "All Files", "*", "Open File" ], [filename])
  RETURN filename
END FUNCTION
}
FUNCTION fglped_filedlg()
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  IF _isLocal() THEN
    CALL ui.interface.frontCall("standard","openfile",[os.Path.pwd(),"Form Files","*.per","Please choose a form"],[fname])
  ELSE
    LET r1.title="Please choose a file"
    LET r1.opt_root_dir=os.Path.pwd()
    LET r1.types[1].description="Genero files (*.4gl)"
    LET r1.types[1].suffixes="*.4gl"
    LET r1.types[2].description="Form files (*.per)"
    LET r1.types[2].suffixes="*.per"
    LET r1.types[3].description="All files (*.*)"
    LET r1.types[3].suffixes="*.*"
    LET fname= filedlg_open(r1.*)
  END IF
  RETURN fname
END FUNCTION

FUNCTION split_src(src)
  DEFINE src STRING
  DEFINE tok base.StringTokenizer
  LET tok=base.StringTokenizer.create(src,"\n")
END FUNCTION

FUNCTION initCRC32Table()
  DEFINE c,cshift,n,magic,k INT
  LET magic=util.Integer.parseHexString("EDB88320")
  FOR n=1 TO 256
    LET c=n-1
    FOR k=1 TO 8
      LET cshift=util.Integer.shiftRight(c,1)
      LET c=IIF(util.Integer.testBit(c,0),
                util.Integer.xor(magic,cshift),
                cshift)
    END FOR
    LET m_CRCTable[n] = c
    --DISPLAY "m_CRCTable[",n-1,",]=",c
  END FOR
END FUNCTION

FUNCTION crc32(str)
  DEFINE str STRING
  DEFINE big BIGINT
  DEFINE start DATETIME YEAR TO FRACTION(2)
  LET start=CURRENT
  LET big=crc32int(str)
  DISPLAY sfmt("time for crc32 of %1 bytes:%2",str.getLength(),CURRENT-start)
  RETURN big
END FUNCTION

FUNCTION crc32int(str)
  DEFINE str,ch STRING
  DEFINE crc,len,i,code,idx,mask32,res,highbit INT
  DEFINE big BIGINT
  LET crc=-1
  LET len=str.getLength()
  
  FOR i = 1 TO len
    LET ch=str.getCharAt(i)
    LET code=ORD(ch)
    LET idx=util.Integer.and(util.Integer.xor(crc,code),255)
    LET crc= util.Integer.xor(util.Integer.shiftRight(crc,8),m_CRCTable[idx+1])
  END FOR
  
  LET res=util.Integer.xor(crc,-1)
  LET big=res
  IF util.Integer.testBit(res,31) THEN --highest bit set
    --we need to add 1000 0000 0000 0000 0000 0000 0000 0000
    -- == 0x80000000
    LET big=HIGHBIT32+util.Integer.clearBit(res,31)
  END IF
  RETURN big
END FUNCTION

FUNCTION savelines()
  DEFINE i,len INT
  CALL m_savedlines.clear()
  LET len=m_orglines.getLength()
  FOR i=1 TO len
    LET m_savedlines[i]=m_orglines[i].line
  END FOR
  LET m_modified=FALSE
END FUNCTION

FUNCTION restorelines()
  DEFINE i,len INT
  CALL m_orglines.clear()
  LET len=m_savedlines.getLength()
  FOR i=1 TO len
    LET m_orglines[i].line=m_savedlines[i]
    LET m_orglines[i].orgnum=i
  END FOR
  LET m_modified=FALSE
END FUNCTION
