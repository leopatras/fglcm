IMPORT util
IMPORT os
CONSTANT S_ERROR="Error"
--error image
CONSTANT IMG_ERROR="stop"
CONSTANT S_TYPE_CHANGED="typeChanged"
CONSTANT S_CLOSED="closed"

TYPE proparr_t DYNAMIC ARRAY OF STRING

DEFINE cm STRING
DEFINE m_error_line STRING
DEFINE m_cline,m_ccol INT
DEFINE m_srcfile STRING
DEFINE m_src STRING
DEFINE m_title STRING
DEFINE compile_arr DYNAMIC ARRAY OF STRING
DEFINE m_CRCTable ARRAY[256] OF INTEGER
CONSTANT HIGHBIT32=2147483648 -- == 0x80000000
{
DEFINE cmRec RECORD
    from RECORD
      line INT,
      ch INT
    END RECORD,
    to RECORD
      line INT,
      ch INT
    END RECORD,
    text DYNAMIC ARRAY OF STRING,
    removed DYNAMIC ARRAY OF STRING,
    origin STRING,
    full STRING, --only used for debugging
    cursor1 RECORD
      line INT,
      ch INT
    END RECORD,
    proparr proparr_t,
    vm BOOLEAN  --we set this to true whenever 4GL wants to change values
END RECORD
}

DEFINE m_orglines DYNAMIC ARRAY OF RECORD
    line STRING,
    orgnum INT
END RECORD

DEFINE cmRec RECORD
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
    cursor1 RECORD
      line INT,
      ch INT
    END RECORD,
    cursor2 RECORD
      line INT,
      ch INT
    END RECORD,
    proparr proparr_t,
    vm BOOLEAN  --we set this to true whenever 4GL wants to change values
END RECORD

MAIN
  DEFINE dummy INT
  CALL initCRC32Table()
  CALL edit_source(arg_val(1)) RETURNING dummy
END MAIN

--main INPUT to edit the form, everything is called from here
FUNCTION edit_source(fname)
  DEFINE fname STRING
  DEFINE proparr proparr_t
  DEFINE src,src_copy,compmess STRING
  DEFINE changed INTEGER
  DEFINE tmpname,ans,result,cname,saveasfile STRING
  --IF ui.Window.forName("screen") IS NULL THEN
  --  OPEN WINDOW screen WITH FORM "cm"
  --ELSE
    OPEN FORM f FROM "cm"
    DISPLAY FORM f
  --END IF
  LET changed=1
  IF fname IS NULL THEN
    LET m_srcfile=NULL
    LET src=file_new()
  ELSE
    LET m_srcfile=fname
    LET src=file_read(m_srcfile)
    IF src IS NULL THEN
      IF (ans:=fgl_winquestion("fglped",sfmt("The file \"%1\" cannot be found, create new?",m_srcfile),"yes","yes|no|cancel","question",0))="cancel" THEN
        RETURN 1
      END IF
      LET src=file_new()
      IF ans="yes" THEN
        IF NOT my_write(m_srcfile,src) THEN
          EXIT PROGRAM 1
        END IF
      ELSE
        EXIT PROGRAM 1
      END IF
    END IF
  END IF
  LET tmpname=setCurrFile(m_srcfile,tmpname)
  LET src_copy=src
  INITIALIZE cmRec.* TO NULL
  LET cmRec.full=src
  LET cmRec.vm=TRUE
  LET cm=util.JSON.stringify(cmRec)
  OPTIONS INPUT WRAP
  INPUT BY NAME cm WITHOUT DEFAULTS ATTRIBUTE(accept=FALSE,cancel=FALSE)
    ON ACTION close
      EXIT INPUT
    ON ACTION complete
      --LET src=update() 
      LET m_src=sync() 
      IF NOT my_write(tmpname,m_src) THEN
        EXIT INPUT
      END IF
      LET cmRec.proparr=complete(tmpname)
      LET cm=util.JSON.stringify(cmRec)
      DISPLAY "cm:",cm
      DISPLAY cm TO cm
    --ON ACTION paste
    --  DISPLAY "paste"
    --ON KEY(CONTROL-V)
    --  DISPLAY "paste2"
      LET m_src=NULL
    ON ACTION compile
      LET src=update() 
      LET compmess = saveAndCompile(tmpname,src,1)
      IF compmess IS NOT NULL THEN
        CALL show_compile_error(src,1)
      ELSE
        MESSAGE "Compile ok"
      END IF
    ON ACTION open
      LET src = update()
      IF (ans:=checkFileSave(src,src_copy))="cancel" THEN CONTINUE INPUT END IF
      IF ans="no" THEN 
        LET src=src_copy 
        CALL display_by_name_src(src)
      END IF
      --LET open_copy = src
      LET src_copy = src
      --LET m_infiledlg=1
      LET cname = fglped_filedlg()
      --LET m_infiledlg=0
--LABEL doOpen:
      IF cname IS NOT NULL THEN
        LET src=file_read(cname)
        IF src IS NULL THEN
          LET src=src_copy
          CALL fgl_winmessage(S_ERROR,sfmt("Can't read:%1",cname),IMG_ERROR)
        ELSE
          LET src_copy = src
          LET tmpname = setCurrFile(cname,tmpname)
          CALL display_by_name_src(src)
          --CALL close_sc_window()
          --GOTO dopreview
        END IF
      ELSE
        --LET src = open_copy
        --CALL display_by_name_src(src)
      END IF
    ON ACTION sync
      DISPLAY "sync"
      LET src=sync()
    ON ACTION save
      DISPLAY "save"
      IF isNewFile() THEN
        GOTO dosaveas
      END IF
      LET src=update()
      IF NOT file_write(m_srcfile,src) THEN
        CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",m_srcfile),IMG_ERROR)
      ELSE
        MESSAGE "saved:",m_srcfile
        LET src_copy=src
      END IF
    ON ACTION saveas
      DISPLAY "saveas"
LABEL dosaveas:
      IF (saveasfile:=fglped_saveasdlg(m_srcfile)) IS NOT NULL THEN
        IF NOT file_write(saveasfile,src) THEN
          CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",saveasfile),IMG_ERROR)
        ELSE
          LET tmpname=setCurrFile(saveasfile,tmpname)
          LET src_copy=src
          CALL mysetTitle()
          CALL display_by_name_src(src)
        END IF
      END IF
  END INPUT
  CALL delete_tmpfiles(tmpname) 
  --CALL close_sc_window()
  RETURN 0
END FUNCTION

FUNCTION update()
  DEFINE newVal STRING
  DEFINE src STRING
  --LET newVal=fgl_dialog_getbuffer()
  CALL ui.Interface.frontCall("webcomponent","call",["formonly.cm","getData"],[newVal])
  CALL util.JSON.parse(newVal,cmRec)
  DISPLAY "cm:",util.JSON.stringify(cmRec)
  DISPLAY "----"
  LET src=cmRec.full
  LET m_cline=cmRec.cursor1.line+1
  LET m_ccol=cmRec.cursor1.ch+1
  DISPLAY cmRec.full
  DISPLAY "----"
  INITIALIZE cmRec.* TO NULL
  LET cm=util.JSON.stringify(cmRec)
  DISPLAY cm TO cm
  --LET cm=newVal
  RETURN src
END FUNCTION

FUNCTION sync()
  DEFINE newVal,line,src STRING
  DEFINE orgnum,idx,i,j,z,len,insertpos INT
  DEFINE crc BIGINT
  --DEFINE src STRING
  LET newVal=fgl_dialog_getbuffer()
  DISPLAY "newVal:",newVal
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
      DISPLAY sfmt("patch line:%1 from:'%2' to:'%3'",orgnum,m_orglines[orgnum].line,line)
      LET m_orglines[orgnum].line=line
    ELSE
      DISPLAY sfmt("index out of range:%1 m_orglines.getLength():%2",orgnum,m_orglines.getLength())
    END IF
  END FOR
  FOR i=cmRec.removed.getLength() TO 1 STEP -1
    LET idx=cmRec.removed[i].idx+1
    LET len=cmRec.removed[i].len
    DISPLAY sfmt("delete lines:%1-%2",idx,idx+len-1)
    FOR j=1 TO len
      DISPLAY "delete line:'",m_orglines[idx].line,"'"
      CALL m_orglines.deleteElement(idx)
    END FOR
  END FOR
  LET j=1
  FOR i=1 TO cmRec.inserts.getLength()
    LET orgnum=cmRec.inserts[i].orgnum+1
    WHILE j<=m_orglines.getLength()
      IF m_orglines[j].orgnum==orgnum THEN
        LET len=cmRec.inserts[i].ilines.getLength()
        DISPLAY sfmt("insert %1 new lines at:%2",len,j+1)
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
  LET src=arr2String()
  LET crc=crc32(src)
  IF crc<>cmRec.crc THEN
    --IF src.getLength()<>cmRec.full.getLength() THEN
    --DISPLAY sfmt("full len %1 != computed getLength %2",cmRec.full.getLength(),src.getLength())
    CALL fgl_winmessage("Error",sfmt("crc local %1 != crc codemirror %2",crc,cmRec.crc),"error")
    DISPLAY sfmt("crc local %1 != crc codemirror %2",crc,cmRec.crc)
  ELSE
    --IF src<>cmRec.full THEN
    --  DISPLAY "src!=full"
    --ELSE
    DISPLAY "ok!!! src==full"
    --END IF
  END IF
  --DISPLAY src
  DISPLAY ">>----"
  INITIALIZE cmRec.* TO NULL
  --renumber
  FOR i=m_orglines.getLength() TO 1 STEP -1
    LET m_orglines[i].orgnum=i
  END FOR
  --LET cm=util.JSON.stringify(cmRec)
  --DISPLAY cm TO cm
  --LET cm=newVal
  RETURN src
END FUNCTION

FUNCTION jump_to_line(linenum,col,line2,col2)
  DEFINE linenum,col,line2,col2 INT
  INITIALIZE cmRec.* TO NULL
  LET cmRec.cursor1.line=linenum-1
  LET cmRec.cursor1.ch=col-1
  LET cmRec.vm=TRUE
  LET cm=util.JSON.stringify(cmRec)
  --DISPLAY "jump_to_line:",cm
  DISPLAY cm TO cm
END FUNCTION

FUNCTION display_by_name_src(src)
  DEFINE src STRING
  INITIALIZE cmRec.* TO NULL
  LET cmRec.vm=TRUE
  LET cmRec.full=src
  LET cm=util.JSON.stringify(cmRec)
  DISPLAY cm TO cm
END FUNCTION

FUNCTION saveAndCompile(fname,src,showerror)
  DEFINE fname STRING
  DEFINE src STRING
  DEFINE showerror INT 
  DEFINE compmess STRING
  IF file_write(fname,src) THEN
    LET compmess=compile_source(fname,showerror,0)
    IF compmess IS NOT NULL AND showerror THEN
      CALL show_compile_error(src,1)
    END IF
  ELSE 
    LET m_error_line=sfmt("Can't write to:%1",m_srcfile)
    IF showerror THEN
      CALL fgl_winmessage(S_ERROR,m_error_line,IMG_ERROR)
    END IF
  END IF
  RETURN compmess
END FUNCTION

FUNCTION compile_source(fname,showmessage,proposals)
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
    LET showmessage=0
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
    IF showmessage THEN
      CALL fgl_winmessage(S_ERROR,mess,IMG_ERROR)
    END IF
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
  LET compmess=compile_source(fname,0,1)
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
  DISPLAY "ERROR:",errstr
  EXIT PROGRAM 1
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

FUNCTION my_write(fname,str)
  DEFINE fname STRING
  DEFINE str STRING
  IF NOT file_write(fname,str) THEN
    CALL fgl_winmessage(S_ERROR,sfmt("Can't write to:%1",fname),IMG_ERROR)
    RETURN FALSE
  END IF
  DISPLAY "did write to:",fname
  RETURN TRUE
END FUNCTION


--displays the first error in the status line with the compile errors
--returns the error line
FUNCTION show_compile_error(txt,jump)
  DEFINE txt STRING
  DEFINE jump INT
  DEFINE idx INT
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
          ERROR m_error_line
          IF linenumstr="0" THEN 
            LET linenum=1
          END IF
          IF jump THEN
            CALL jump_to_line(linenum,col,line2numstr,col2)
          END IF
          RETURN 
        END IF
      END IF
      EXIT WHILE
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
  WHENEVER ERROR CONTINUE
  CALL ch.openFile(srcfile,"r")
  LET linenum=1
  IF status == 0 THEN
    WHILE NOT ch.isEof()
      LET line=ch.readLine()
      IF ch.isEof() AND line.getLength()==0 THEN
        EXIT WHILE
      END IF
      LET m_orglines[linenum].line=line
      LET m_orglines[linenum].orgnum=linenum
      LET linenum=linenum+1
      -- do something
    END WHILE
    CALL ch.close()
  END IF
  --DISPLAY "m_orglines:",util.JSON.stringify(m_orglines),",len:",m_orglines.getLength()
  WHENEVER ERROR STOP
  RETURN arr2String()
END FUNCTION

FUNCTION arr2String()
  DEFINE buf base.StringBuffer
  DEFINE len,i INT
  LET buf=base.StringBuffer.create()
  LET len=m_orglines.getLength()
  FOR i=1 TO len
    CALL buf.append(m_orglines[i].line)
    IF i<>len THEN
      CALL buf.append("\n")
    END IF
  END FOR
  RETURN buf.toString()
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

FUNCTION file_write_int(srcfile,src,mode)
  DEFINE srcfile STRING
  DEFINE src STRING
  DEFINE mode STRING
  DEFINE ch base.Channel
  DEFINE result,mystatus INT
  DEFINE idx,old,len INT
  DEFINE line STRING
  LET  ch=base.channel.create()
  CALL ch.setDelimiter("")
  WHENEVER ERROR CONTINUE
  CALL ch.openFile(srcfile,mode)
  LET mystatus=status
  WHENEVER ERROR stop
  IF mystatus <> 0 THEN
    LET result=0
  ELSE
    IF m_src IS NOT NULL THEN
      LET len=m_orglines.getLength()
      FOR idx=1 TO len
        IF idx<>len THEN
          CALL ch.writeLine(m_orglines[idx].line)
        ELSE
          CALL ch.write(m_orglines[idx].line)
        END IF
      END FOR
    ELSE
      LET old=1
      WHILE (idx:=src.getIndexOf("\n",old))>0
        LET line=src.subString(old,idx-1)
        LET src=src.subString(idx+1,src.getLength())
        CALL ch.writeLine(line)
      END WHILE
      IF src.getLength()>0 THEN
        CALL ch.write(src)
      END IF
    END IF
    LET result=TRUE
    CALL ch.close()
  END IF
  RETURN result
END FUNCTION

FUNCTION file_write(srcfile,src)
  DEFINE srcfile STRING
  DEFINE start,t DATETIME YEAR TO FRACTION(2)
  DEFINE src STRING
  DEFINE result INT
  LET start=CURRENT
  LET result=file_write_int(srcfile,src,"w")
  DISPLAY "time for file_write:",CURRENT-start
  RETURN result
END FUNCTION

FUNCTION file_append(srcfile,src)
  DEFINE srcfile STRING
  DEFINE src STRING
  RETURN file_write_int(srcfile,src,"a")
END FUNCTION

FUNCTION file_on_windows()
  IF fgl_getenv("WINDIR") IS NULL THEN
    RETURN 0
  ELSE
    RETURN 1
  END IF
END FUNCTION

FUNCTION file_get_output(program,arr)
  DEFINE program,linestr STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE mystatus,idx INTEGER
  DEFINE c base.Channel
  LET c = base.channel.create()
  CALL c.setDelimiter("")
  WHENEVER ERROR CONTINUE
  CALL c.openpipe(program,"r")
  LET mystatus=status
  WHENEVER ERROR STOP
  --DISPLAY "file_get_output:",program
  IF mystatus THEN
    DISPLAY "error in file_get_output(program,arr)"
    --LET file_errstr=err_get(mystatus)
    RETURN
  END IF
  --DISPLAY "file_get_output:",program
  CALL arr.clear()
  WHILE (linestr:=c.readline()) IS NOT NULL
    LET idx=idx+1
    --DISPLAY "LINE ",idx,"=",linestr
    LET arr[idx]=linestr
  END WHILE
  CALL c.close()
  RETURN
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

FUNCTION checkFileSave(src,src_copy)
  DEFINE src STRING
  DEFINE src_copy STRING
  DEFINE ans STRING
  DEFINE dummy INT
  IF checkChanged(src,src_copy) THEN
    IF (ans:=fgl_winquestion("fglped",sfmt("Save changes to %1?",m_title),"yes","yes|no|cancel","question",0))="yes" THEN
      IF isNewFile() THEN
        LET m_srcfile=fglped_saveasdlg(m_srcfile)
        IF m_srcfile IS NULL THEN
          RETURN "cancel"
        END IF
      END IF
      CALL my_write(m_srcfile,src) RETURNING dummy
    END IF
  END IF
  RETURN ans
END FUNCTION

FUNCTION file_new()
  CALL m_orglines.clear()
  RETURN ""
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

FUNCTION fglped_filedlg()
  DEFINE filename STRING
  CALL ui.Interface.frontCall("standard","openfile", ["", "All Files", "*.*", "Open File" ], [filename])
  RETURN filename
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

