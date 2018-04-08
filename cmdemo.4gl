OPTIONS SHORT CIRCUIT
IMPORT os
IMPORT util
IMPORT FGL fgldialog
IMPORT FGL demo_load
IMPORT FGL demo_make_db
IMPORT FGL demo
IMPORT FGL fglped_fileutils

SCHEMA demo

DEFINE demos DYNAMIC ARRAY OF RECORD LIKE demos.*
DEFINE topics DYNAMIC ARRAY OF RECORD LIKE topics.*
DEFINE m_home STRING --homedir
MAIN
    DEFINE readme STRING
    DEFINE fgldir,cmdir STRING
    LET fgldir=fgl_getenv("FGLDIR")
    IF fgldir IS NULL THEN
      CALL myerr("FGLDIR must be set")
    END IF

    OPTIONS INPUT WRAP
    OPEN FORM main FROM "cmdemo"
    DISPLAY FORM main
    LET m_home=fgl_getenv("FGLCMHOME")
    IF m_home IS NULL THEN
      LET m_home=os.Path.join(os.Path.pwd(),"home")    
    END IF
    IF NOT os.Path.exists(m_home) OR NOT os.Path.isDirectory(m_home) THEN
      CALL myerr(sfmt("No valid setting for home:%1",m_home))
    END IF
    LET cmdir=os.Path.dirname(arg_val(0))
    IF os.Path.fullPath(cmdir)==os.Path.fullPath(m_home) THEN
      CALL myerr(sfmt("FGLCMHOME:%1 must not be equal to FGLCMDIR:%2",m_home,cmdir))
    END IF
    IF NOT os.Path.chDir(os.Path.join(fgldir,"demo")) THEN
      CALL myerr("chdir")
    END IF

    CONNECT TO ":memory:+driver='sqlite'" 
    CALL demo_make_db.create_tables()
    CALL demo_load.load_demo()

    CALL fetch_topics()
    DIALOG ATTRIBUTES(FIELD ORDER FORM, UNBUFFERED)
        DISPLAY ARRAY topics TO topics.*
        BEFORE ROW
            CALL fetch_demos(topics[arr_curr()].*)
            LET readme = readfile(os.Path.join(topics[arr_curr()].dirname, "README"))
        END DISPLAY
        DISPLAY ARRAY demos TO demos.*
        BEFORE ROW
            IF arr_curr() > 0 THEN
                CALL check_context(DIALOG,demos[arr_curr()].*)
            END IF
        ON ACTION show_or_run ATTRIBUTE(DEFAULTVIEW=YES)
            IF arr_curr() > 0 THEN
                CALL run_demo(demos[arr_curr()].*)
            END IF
        ON ACTION copy2fiddle ATTRIBUTE(DEFAULTVIEW=YES)
            IF arr_curr() > 0 THEN
                CALL copy2fiddle(demos[arr_curr()].*)
            END IF
        END DISPLAY
        INPUT BY NAME readme END INPUT
    ON ACTION CANCEL
        CALL myerr("Cancel")
    END DIALOG
END MAIN

FUNCTION fetch_topics()
    DEFINE topic RECORD LIKE topics.*
    DEFINE n INT
    LET n = 0
    DECLARE topic CURSOR FOR SELECT * INTO topic.* FROM topics
    FOREACH topic
        LET n = n + 1
        LET topics[n].* = topic.*
    END FOREACH
END FUNCTION

FUNCTION fetch_demos(topic)
    DEFINE topic RECORD LIKE topics.*
    DEFINE demo RECORD LIKE demos.*
    DEFINE n INT

    CALL demos.clear()
    LET n = 0
    DECLARE demo CURSOR FOR SELECT * INTO demo.* FROM demos
        WHERE dirname = topic.dirname
    FOREACH demo
        CASE demo.type
        WHEN "V"
            LET demo.type = "services"
        WHEN "B"
            LET demo.type = "file"
        END CASE
        LET n = n + 1
        LET demos[n].* = demo.*
    END FOREACH
END FUNCTION

FUNCTION check_context(d,demo)
    DEFINE d ui.Dialog
    DEFINE demo RECORD LIKE demos.*
    CASE demo.type
      WHEN "services"
        CALL d.setActionText("show_or_run","Run Demo")
        CALL d.setActionText("copy2fiddle","Use as Fiddle")
      WHEN "file"
        CALL d.setActionText("show_or_run","Show File")
        IF is4GLFile(demo.program) THEN
          CALL d.setActionText("copy2fiddle","Use as Fiddle main")
        ELSE
          CALL d.setActionText("copy2fiddle","Copy into Fiddle")
        END IF
   END CASE
END FUNCTION

FUNCTION mycopy(src,dest)
  DEFINE src,dest STRING
  IF NOT os.Path.copy(src,dest) THEN
    CALL myerr(sfmt("Cant copy:%1 -> %2",src,dest))
  END IF
END FUNCTION

FUNCTION copyfull2main(fullname)
    DEFINE fullname,main4gl STRING
    IF NOT is4GLFile(fullname) THEN
      LET fullname=fullname,".4gl"
    END IF
    LET main4gl=os.Path.join(m_home,"main.4gl")
    CALL mycopy(fullname,main4gl)
END FUNCTION

FUNCTION cutExt(name)
  DEFINE name,ext STRING
  LET ext=os.Path.extension(name)
  IF ext IS NULL THEN
    RETURN name
  END IF
  RETURN name.subString(1,name.getLength()-(ext.getLength()+1))
END FUNCTION

FUNCTION copy2fiddle(demo)
    DEFINE demo RECORD LIKE demos.*
    DEFINE prog,dest,dirname,fullname,result,args STRING
    DEFINE isUnix BOOLEAN
    DEFINE space_idx INT
    LET dest=os.Path.join(m_home,demo.program)
    LET isUnix = fgl_getenv("WINDIR") IS NULL
    LET dirname=demo.dirname
    IF NOT isUnix THEN
       LET dirname = unixToDosPath(dirname)
    END IF
    LET prog=demo.program
    IF (space_idx:=prog.getIndexOf(" ",1))<>0 THEN
      LET args=prog.subString(space_idx+1,prog.getLength())
      LET prog=prog.subString(1,space_idx-1)
    ELSE
      LET args=demo.args
    END IF
    LET fullname=os.Path.join(dirname,prog)
    CASE demo.type
      WHEN "services"
        IF fgldialog.fgl_winQuestion("Attention",
              sfmt("Do you want to replace your existing Fiddle with the %1 program ?",
               demo.program),"yes","yes|no","question",0)=="no" THEN
          RETURN
        END IF
        CALL rmHome()
        CALL copyAllAssets(dirname,prog,IIF(args IS NULL," ",args))
        CALL copyfull2main(fullname)
        IF args IS NOT NULL THEN
          CALL createArgsFile(args)
        END IF
        LET result="main.4gl"
      WHEN "file"
        IF is4GLFile(demo.program) THEN
          IF fgldialog.fgl_winQuestion("Attention",
              sfmt("Do you want to replace your existing Fiddle with the %1 program ?",
               cutExt(prog)),"yes","yes|no","question",0)=="no" 
          THEN
            RETURN
          END IF
          CALL rmHome()
          CALL copySameBaseFiles(dirname,prog)
          CALL copyfull2main(fullname)
          LET result="main.4gl"
        ELSE
          IF os.Path.exists(dest) THEN
            IF fgldialog.fgl_winQuestion("Attention",
              sfmt("Do you want to replace %1 in your home with %2 ?",
               dest,fullname),"yes","yes|no","question",0)=="no" 
            THEN
              RETURN
            END IF
          END IF
          CALL mycopy(fullname,dest)
          LET result=demo.program
        END IF
     OTHERWISE
       CALL myerr("Invalid case")
   END CASE
   DISPLAY "COPY2FIDDLE:",result
   EXIT PROGRAM 0
END FUNCTION

--if base is "foo.4gl" copies foo.per, foo.data etc
FUNCTION copySameBaseFiles(dirname,prog)
  DEFINE dirname,prog,args,base,name STRING
  DEFINE exts DYNAMIC ARRAY OF STRING
  DEFINE i INT
  CALL util.JSON.parse('[".per",".data",".test"]',exts)
  FOR i=1 TO exts.getLength()
    LET base=cutExt(prog),exts[i]
    LET name=os.Path.join(dirname,base)
    DISPLAY "name:",name
    IF os.Path.exists(name) THEN
      DISPLAY "copy to:",os.Path.join(m_home,base)
      CALL mycopy(name,os.Path.join(m_home,base))
    END IF
  END FOR
  IF dirname="Sax" THEN
    LET base="customer.xml"
    LET name=os.Path.join(dirname,base) --Sax demo
    IF os.Path.exists(name) THEN
      CALL mycopy(name,os.Path.join(m_home,base))
    END IF
  END IF
END FUNCTION

FUNCTION rmHome()
  DEFINE dirhandle INTEGER
  DEFINE shortname,fname STRING
  LET dirhandle = os.Path.diropen(m_home)
  IF dirhandle == 0 THEN 
    CALL myerr(sfmt("Can't open home directory:%1",m_home))
  END IF
  WHILE ( shortname := os.Path.dirnext(dirhandle) ) IS NOT NULL
    IF shortname=="." OR shortname==".." THEN
      CONTINUE WHILE
    END IF
    LET fname=os.Path.join(m_home,shortname)
    IF os.Path.isDirectory(fname) THEN
      CONTINUE WHILE
    END IF
    IF NOT os.Path.delete(fname) THEN
      CALL myerr(SFMT("Can't delete:%1",fname))
    END IF
  END WHILE
  CALL os.Path.dirClose(dirhandle)
END FUNCTION

FUNCTION copyAllAssets(dirpath,prog,args)
  DEFINE dirpath STRING
  DEFINE prog,args,base STRING
  DEFINE dirhandle,i INTEGER
  DEFINE shortname,fname,ext,assetbase STRING
  DEFINE modules,notused,assets DYNAMIC ARRAY OF STRING
  LET modules[1]=prog
  CALL getAllImportedModules(dirpath,prog,modules)
  DISPLAY "imported modules of ",prog,".4gl:",util.JSON.stringify(modules)
  LET dirhandle = os.Path.diropen(dirpath)
  IF dirhandle == 0 THEN 
    CALL myerr(sfmt("Can't open directory:%1",dirpath))
  END IF
  WHILE ( shortname := os.Path.dirnext(dirhandle) ) IS NOT NULL
      IF shortname=="." OR shortname==".." THEN
        CONTINUE WHILE
      END IF
      LET fname=os.Path.join(dirpath,shortname)
      IF os.Path.isDirectory(fname) THEN
        CONTINUE WHILE
      END IF
      LET ext=os.Path.extension(fname)
      IF ext IS NULL THEN
        CONTINUE WHILE
      END IF
      IF ext=="42f" OR ext="42m" THEN
        CONTINUE WHILE
      END IF
      LET base=cutExt(shortname)
      IF ext=="4gl" THEN
        IF NOT arrayContainsElement(modules,base) THEN
          LET notused[notused.getLength()+1]=base
          CONTINUE WHILE
        END IF
        IF base==prog THEN --don't copy under the original name
          CONTINUE WHILE
        END IF
      END IF
      IF ext=="per" OR (ext=="4st" AND shortname<>"default.4st") 
         OR ext="data" OR ext="unl" OR ext=="4tb" OR ext=="txt" THEN
        LET assets[assets.getLength()+1]=base,".",ext
        CONTINUE WHILE
      END IF
      --  CALL check_imports(dirpath,shortname,)
      DISPLAY "mycopy ",fname," -> ",os.Path.join(m_home,shortname)
      CALL mycopy(fname,os.Path.join(m_home,shortname))
    END WHILE
    DISPLAY "prog:",prog,",args:",args
    DISPLAY "notused",util.JSON.stringify(notused)
    DISPLAY "assets:",util.JSON.stringify(assets)
    FOR i=1 TO assets.getLength()
      --we filter out .per files which have the same name as unused modules
      LET ext=os.Path.extension(assets[i])
      LET assetbase=cutExt(assets[i])
      --IF NOT arrayContainsElement(notused,assetbase) THEN
        {
        IF assetbase<>prog AND assetbase<>args 
            AND arrayContainsSubStringOfEl(notused,assetbase)
        THEN
          DISPLAY "leave out:",assetbase
          CONTINUE FOR
        END IF
        }
        IF assetbase<>prog AND assetbase<>args
            AND NOT assetInModules(dirpath,assetbase,modules) 
        THEN
          CONTINUE FOR
        END IF
        LET shortname=assetbase,".",ext
        LET fname=os.Path.join(dirpath,shortname)
        DISPLAY "copy:",fname," -> ",os.Path.join(m_home,shortname)
        CALL mycopy(fname,os.Path.join(m_home,shortname))
      --END IF
    END FOR
  CALL os.Path.dirClose(dirhandle)
END FUNCTION

FUNCTION assetInModules(dirpath,assetbase,modules)
  DEFINE dirpath,assetbase STRING
  DEFINE modules DYNAMIC ARRAY OF STRING
  DEFINE i,code INT
  DEFINE cmd,file4gl STRING
  FOR i=1 TO modules.getLength()
    LET file4gl=modules[i],".4gl"
    LET cmd=sfmt("cd %1&&grep -w %2 %3",dirpath,assetbase,file4gl)
    RUN cmd RETURNING code
    DISPLAY "cmd:",cmd,",code:",code
    IF code==0 THEN --found
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

FUNCTION arrayContainsElement(arr,el)
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE el STRING
  RETURN arrayContainsElementInt(arr,el,FALSE)
END FUNCTION

FUNCTION arrayContainsSubStringOfEl(arr,el)
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE el STRING
  RETURN arrayContainsElementInt(arr,el,TRUE)
END FUNCTION

FUNCTION arrayContainsElementInt(arr,el,checkSubString)
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE el STRING
  DEFINE checkSubString BOOLEAN
  DEFINE arr_el STRING
  DEFINE i,len INT

  LET len=arr.getLength()
  FOR i=1 TO len
    LET arr_el=arr[i]
    IF arr_el==el THEN
      RETURN TRUE
    END IF
    IF checkSubString AND el.getIndexOf(arr_el,1)==1 THEN
      DISPLAY el,".getIndexOf(",arr_el,",1)==1"
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

FUNCTION getAllImportedModules(dirpath,prog,modules)
  DEFINE dirpath,prog STRING
  DEFINE modules DYNAMIC ARRAY OF STRING
  DEFINE c base.Channel
  DEFINE cmd,tmpname,name STRING
  DEFINE code INT
  DEFINE TXRec RECORD
    type CHAR(1),
    id INT,
    pid_or_whatever STRING,
    what_or_id STRING,
    name_or_pid STRING,
    what2 STRING,
    unused STRING,
    qualifier STRING
  END RECORD
  LET tmpname=os.Path.makeTempName()
  LET cmd=sfmt("cd %1&&fglcomp -TX %2>%3 2>&1",dirpath,prog,tmpname)
  RUN cmd RETURNING code
  IF code THEN
    DISPLAY "failed to compile:",prog
    RUN "cat "||tmpname
    GOTO cleanup
  END IF
  LET c=base.Channel.create()
  CALL c.setDelimiter("^")
  TRY
  CALL c.openFile(tmpname,"r")
  WHILE c.read([TXRec.*])
    --DISPLAY "type:",TXRec.type,",what2:",TXRec.what2
    IF TXRec.type=="F" THEN
      LET TXRec.what2="MODULE"
      LET TXRec.qualifier="imported"
      LET TXRec.name_or_pid=cutExt(TXRec.pid_or_whatever)
    END IF
    IF TXRec.what2=="MODULE" AND TXRec.qualifier=="imported"  THEN
      LET name=TXRec.name_or_pid
      IF NOT arrayContainsElement(modules,name) THEN
        LET modules[modules.getLength()+1]=name
        DISPLAY "imported module of ",prog,":",name
        --recursive lookup the imported modules of the imported modules
        CALL getAllImportedModules(dirpath,name,modules)
      END IF
    END IF
  END WHILE
  CALL c.close()
  END TRY
LABEL cleanup:
  CALL os.Path.delete(tmpname) RETURNING code
END FUNCTION

FUNCTION createArgsFile(args)
  DEFINE args STRING
  DEFINE c base.Channel
  LET c=base.Channel.create()
  CALL c.openFile(os.Path.join(m_home,"main.args"),"w")
  CALL c.writeNoNL(args)
  CALL c.close()
END FUNCTION

FUNCTION run_demo(demo)
    DEFINE demo RECORD LIKE demos.*
    DEFINE cmd STRING
    DEFINE isUnix BOOLEAN

    IF demo.program IS NULL THEN RETURN END IF

    CASE demo.type
    WHEN "services"
        -- Run the command: Check if there is a script to run the demo
        LET isUnix = fgl_getenv("WINDIR") IS NULL
        IF NOT isUnix THEN
            LET demo.dirname = unixToDosPath(demo.dirname)
        END IF
        LET cmd = os.Path.join(demo.dirname, demo.program), IIF(isUnix, ".sh", ".bat")
        IF os.Path.exists(cmd) THEN -- Script
            IF isUnix THEN
                LET cmd = "sh ", cmd
            END IF
            LET cmd = cmd, " ", demo.args
        ELSE -- 4gl program
            LET cmd = "cd ", demo.dirname, " && fglrun ", demo.program, " ", demo.args
        END IF
        RUN cmd WITHOUT WAITING
    WHEN "file"
        CALL showfile(os.Path.join(demo.dirname, demo.program))
    OTHERWISE
        -- Can't happen?
    END CASE
END FUNCTION

FUNCTION unixToDosPath(path)
    DEFINE path STRING
    DEFINE buf base.StringBuffer
    LET buf = base.StringBuffer.create()
    CALL buf.append(path)
    CALL buf.replace("/", "\\", 0)
    RETURN buf.toString()
END FUNCTION

FUNCTION readfile(fn)
    DEFINE fn STRING
    DEFINE t TEXT
    DEFINE s STRING

    LOCATE t IN FILE fn
    LET s = t
    RETURN s
END FUNCTION

FUNCTION myerr(err)
  DEFINE err STRING
  DISPLAY "ERROR:",err
  EXIT PROGRAM 1
END FUNCTION