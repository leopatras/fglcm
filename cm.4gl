OPTIONS SHORT CIRCUIT
IMPORT util
IMPORT os
IMPORT FGL fgldialog
IMPORT FGL fglped_md_filedlg
IMPORT FGL fglped_fileutils
CONSTANT S_ERROR="Error"
--error image
CONSTANT IMG_ERROR="stop"
CONSTANT S_CANCEL="*cancel*"

TYPE proparr_t DYNAMIC ARRAY OF STRING
DEFINE m_error_line STRING
DEFINE m_cline,m_ccol INT
DEFINE m_srcfile STRING
DEFINE m_title STRING
DEFINE compile_arr DYNAMIC ARRAY OF STRING
DEFINE m_CRCProg STRING
--DEFINE m_CRCTable ARRAY[256] OF INTEGER
DEFINE m_lastCRC BIGINT
DEFINE m_modified BOOLEAN
DEFINE m_IsNewFile BOOLEAN
DEFINE m_mainFormOpen BOOLEAN
DEFINE m_previewHidden BOOLEAN
DEFINE m_NewFileExt STRING
DEFINE m_cmdIdx INT
DEFINE m_lastCompiled4GL STRING
DEFINE m_lastCompiledPER STRING
DEFINE m_locationhref STRING
DEFINE m_extURL STRING --external form viewer URL
DEFINE _on_mac STRING --cache the file_on_mac
DEFINE m_IsFiddle BOOLEAN
DEFINE m_InitSeen BOOLEAN
--CONSTANT HIGHBIT32=2147483648 -- == 0x80000000

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
    cmCommand STRING, --editor command to perform in CodeMirror
    fileName STRING, --the server side file name
    locationhref STRING, --the server side location
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
    END RECORD,
    flushTimeout INT
END RECORD

DEFINE m_cmRec CmType
DEFINE m_cm STRING
DEFINE m_arg_0 STRING
DEFINE m_args DYNAMIC ARRAY OF STRING
MAIN
  DEFINE i INT
  FOR i=1 TO num_args()
    LET m_args[i]=arg_val(i)
  END FOR
  LET m_arg_0=arg_val(0)
  CALL fglcm_main()
END MAIN

FUNCTION setArgs(arg0,args)
  DEFINE arg0 STRING
  DEFINE args DYNAMIC ARRAY OF STRING
  LET m_arg_0=arg0
  LET m_args=args
END FUNCTION

FUNCTION fglcm_main()
  DEFINE result INT
  LET m_IsFiddle=fgl_getenv("FGLFIDDLE") IS NOT NULL
  CALL ui.Interface.loadStyles("fglcm")
  --CALL initCRC32Table()
  CALL loadKeywords()
  LET m_lastCRC=NULL
  LET m_CRCProg=os.Path.fullPath(myjoin(mydir(my_arg_val(0)),"crc32"))
  DISPLAY "m_CRCProg:",m_CRCProg
  IF NOT os.Path.exists(m_CRCProg) OR NOT os.Path.executable(m_CRCProg) THEN
    LET m_CRCProg=NULL
  END IF
  LET result=edit_source(my_arg_val(1))
  EXIT PROGRAM result
END FUNCTION

FUNCTION my_arg_val(index)
  DEFINE index INT
  IF index==0 THEN
    RETURN m_arg_0
  ELSE
    IF index>=1 AND index <= m_args.getLength() THEN
      RETURN m_args[index]
    END IF
  END IF
  RETURN NULL
END FUNCTION

FUNCTION checkFiddleBar()
  DEFINE f ui.Form
  DEFINE fNode,tb om.DomNode
  DEFINE nlist om.NodeList
  IF m_IsFiddle THEN
    RETURN
  END IF
  --remove the bar when not in fiddle mode
  LET f=getCurrentForm()
  LET fNode=f.getNode()
  LET nlist=fNode.selectByTagName("ToolBar")
  IF nlist.getLength()>0 THEN
    LET tb=nlist.item(1)
    CALL fNode.removeChild(tb)
  END IF
END FUNCTION

FUNCTION mydir(path)
  DEFINE path STRING
  DEFINE dirname STRING
  LET dirname=os.Path.dirname(path)
  IF dirname IS NULL THEN
    LET dirname="."
  END IF
  RETURN dirname
END FUNCTION

FUNCTION myjoin(path1,path2)
  DEFINE path1,path2 STRING
  RETURN os.Path.join(path1,path2)
END FUNCTION

FUNCTION isGBC()
  RETURN ui.Interface.getFrontEndName()=="GBC"
END FUNCTION

FUNCTION getCurrentForm()
  DEFINE w ui.Window
  LET w=ui.Window.getCurrent()
  RETURN w.getForm()
END FUNCTION

FUNCTION setPreviewActionActive(active)
  DEFINE active BOOLEAN
  DEFINE f ui.Form
  DEFINE fNode,item om.DomNode
  DEFINE nlist om.NodeList
  CALL setActionActive("preview",active)
  CALL setActionActive("showpreviewurl",active)
  IF NOT m_IsFiddle THEN
    RETURN
  END IF
  LET f=getCurrentForm()
  LET fnode=f.getNode()
  LET nlist=fnode.selectByPath('//ToolBarItem[@name="preview"]')
  IF nlist.getLength()>0 THEN
    LET item=nlist.item(1)
    CALL f.setElementHidden("preview",NOT active)
  END IF
END FUNCTION

FUNCTION hideOrShowPreview()
  DEFINE f ui.Form
  DEFINE isPER, wasHidden,dummy BOOLEAN
  IF NOT isGBC() THEN
    RETURN
  END IF
  LET f=getCurrentForm()
  LET isPER=(m_IsNewFile AND ((m_NewFileExt IS NOT NULL) AND (m_NewFileExt=="per"))) OR isPERFile(m_srcfile)
  DISPLAY sfmt("hideOrShow m_srcfile:%1,isPERFile:%2,isPER:%3,hidden:%4",
     m_srcfile,isPERFile(m_srcfile),isPER,NOT isPER)
  LET wasHidden=m_previewHidden
  LET m_previewHidden=NOT isPER
  CALL f.setFieldHidden("formonly.webpreview",m_previewHidden)
  IF NOT wasHidden AND m_previewHidden THEN
    CALL os.Path.delete(getSession42f()) RETURNING dummy
    DISPLAY NULL TO webpreview
  END IF  
END FUNCTION

FUNCTION checkMainFormOpen()
  IF NOT isGBC() AND m_mainFormOpen THEN
    RETURN
  END IF
  IF m_mainFormOpen THEN
    CLOSE FORM f
  END IF
  --AND ((m_IsNewFile AND m_NewFileExt=="per") OR isPERFile(m_srcfile))
  --IF isGBC() THEN
  --  OPEN FORM f FROM "cm_webpreview"
  --ELSE
    OPEN FORM f FROM "cm"
  --END IF
  DISPLAY FORM f
  LET m_mainFormOpen=TRUE
  CALL checkFiddleBar()
  CALL hideOrShowPreview()
END FUNCTION

--main INPUT to edit the form, everything is called from here
FUNCTION edit_source(fname)
  DEFINE fname STRING
  DEFINE changed INTEGER
  DEFINE jump_to_error,modified BOOLEAN
  DEFINE tmpname,ans,saveasfile,dummy STRING
  LET changed=1
  IF fname IS NULL THEN
    LET m_srcfile=NULL
    IF file_new(NULL)==S_CANCEL THEN
      RETURN 1
    END IF
  ELSE
    LET m_srcfile=fname
    IF NOT file_read(m_srcfile) THEN
      IF (ans:=fgl_winquestion("fglcm",sfmt("The file \"%1\" cannot be found, create new?",m_srcfile),
          "yes","yes|no|cancel","question",0))=S_CANCEL 
      THEN
        RETURN 1
      END IF
      IF file_new(os.Path.extension(m_srcfile))==S_CANCEL THEN
        RETURN 1
      END IF
      IF ans="yes" THEN
        IF NOT my_write(m_srcfile,FALSE) THEN
          RETURN 1
        END IF
      ELSE
        RETURN 1
      END IF
    END IF
  END IF
  LET tmpname=setCurrFile(m_srcfile,tmpname)
  CALL savelines()
  CALL checkMainFormOpen()
  OPTIONS INPUT WRAP
  INPUT m_cm WITHOUT DEFAULTS FROM cm ATTRIBUTE(accept=FALSE,cancel=FALSE)
    BEFORE INPUT
      CALL DIALOG.setActionActive("run",FALSE)
      CALL setPreviewActionActive(FALSE)
      CALL DIALOG.setActionActive("main4gl",m_IsFiddle)
      CALL DIALOG.setActionActive("mainper",m_IsFiddle)
      CALL DIALOG.setActionActive("browse_demos",m_IsFiddle)
      CALL DIALOG.setActionHidden("main4gl",NOT m_IsFiddle)
      CALL DIALOG.setActionHidden("mainper",NOT m_IsFiddle)
      CALL DIALOG.setActionHidden("browse_demos",NOT m_IsFiddle)
      CALL initialize_when(TRUE)
      CALL compileTmp(tmpname,TRUE)
      CALL display_full(FALSE,FALSE)
      CALL flush_cm()
    ON ACTION fglcm_init ATTRIBUTE(DEFAULTVIEW=NO) --invoked by the editor
      LET m_InitSeen=TRUE
      DISPLAY "init seen"
      DISPLAY m_cm TO cm

    ON ACTION run
      CALL runprog(tmpname)

    ON ACTION preview
      CALL preview_form()

    ON ACTION showpreviewurl
      CALL show_previewurl()

    ON ACTION close_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL sync()
      GOTO action_close
    ON ACTION close
      CALL fcsync()
LABEL action_close:
      IF checkFileSave()=S_CANCEL THEN
        CONTINUE INPUT
      ELSE
        EXIT INPUT
      END IF

    ON ACTION complete
      CALL sync() 
      IF NOT my_write(tmpname,TRUE) THEN
        EXIT INPUT
      END IF
      CALL initialize_when(TRUE)
      LET m_cmRec.proparr=complete(tmpname)
      CALL compile_and_process(tmpname,FALSE) RETURNING dummy
      CALL flush_cm()

    ON ACTION find
      CALL fcsync()
      CALL initialize_when(TRUE)
      LET m_cmRec.cmCommand="find"
      CALL compileTmp(tmpname,FALSE)
      CALL flush_cm()
      
    ON ACTION replace
      CALL fcsync()
      CALL initialize_when(TRUE)
      LET m_cmRec.cmCommand="replace"
      CALL compileTmp(tmpname,FALSE)
      CALL flush_cm()

    ON ACTION gotoline_cm
      CALL sync()
      GOTO action_gotoline
    ON ACTION gotoline
      CALL fcsync()
LABEL action_gotoline:
      CALL do_gotoline()

    ON ACTION update ATTRIBUTE(DEFAULTVIEW=NO) --invoked by the editor
      CALL sync()
      LET jump_to_error=FALSE
      GOTO do_compile
    ON ACTION compile ATTRIBUTE(DEFAULTVIEW=NO)
      CALL fcsync()
      LET jump_to_error=TRUE
LABEL do_compile:
      CALL initialize_when(TRUE)
      CALL compileTmp(tmpname,jump_to_error)
      CALL flush_cm()

    ON ACTION new_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL sync()
      GOTO action_new
    ON ACTION new
      CALL fcsync()
LABEL action_new:
      IF (ans:=checkFileSave())=S_CANCEL THEN CONTINUE INPUT END IF
      CALL initialize_when(TRUE)
      IF file_new(NULL)==S_CANCEL THEN CONTINUE INPUT END IF
      CALL display_full(FALSE,FALSE)
      LET tmpname=setCurrFile("",tmpname)
      CALL compileTmp(tmpname,FALSE)
      CALL hideOrShowPreview()
      CALL flush_cm()

    ON ACTION main4gl
      CALL fcsync()
      LET tmpname=doOpen(tmpname,"main.4gl")

    ON ACTION mainper
      CALL fcsync()
      LET tmpname=doOpen(tmpname,"main.per")
      
    ON ACTION open_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL sync()
      GOTO action_open
    ON ACTION open
      CALL fcsync()
LABEL action_open:
      LET tmpname=doOpen(tmpname,NULL)

    --ON ACTION sync
    --  CALL sync()

    ON ACTION save_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL sync()
      DISPLAY "save_cm"
      GOTO action_save
    ON ACTION save
      DISPLAY "save_topmenu"
      CALL fcsync()
      LET modified=m_modified
LABEL action_save:
      IF isNewFile() THEN
        GOTO dosaveas
      END IF
      IF NOT file_write(m_srcfile,FALSE) THEN
        CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",m_srcfile),IMG_ERROR)
        --TODO: handle this worst case 
      ELSE
        DISPLAY "saved"
        CALL savelines()
        CALL initialize_when(TRUE)
        CALL compileTmp(tmpname,FALSE)
        CALL flush_cm()
        CALL mymessage(sfmt("saved:%1",m_srcfile))
      END IF

    ON ACTION saveas
      DISPLAY "saveas"
LABEL dosaveas:
      IF (saveasfile:=fglped_saveasdlg(m_srcfile)) IS NOT NULL THEN
        IF NOT file_write(saveasfile,FALSE) THEN
          CALL fgl_winmessage(S_ERROR,sfmt("Can't write:%1",saveasfile),IMG_ERROR)
        ELSE
          LET tmpname=setCurrFile(saveasfile,tmpname)
          CALL savelines()
          CALL resetNewFile()
          CALL mysetTitle()
          CALL display_full(TRUE,TRUE)
        END IF
      END IF

    ON ACTION browse_demos
      CALL fcsync()
      LET tmpname=browse_demos(tmpname)
  END INPUT
  CALL delete_tmpfiles(tmpname)
  DISPLAY NULL TO webpreview
  CALL os.Path.delete(getSession42f()) RETURNING dummy
  RETURN 0
END FUNCTION


FUNCTION open_prepare(tmpname)
  DEFINE tmpname STRING
  DEFINE ans STRING
  IF (ans:=checkFileSave())=S_CANCEL THEN 
    RETURN tmpname
  END IF
  CALL initialize_when(TRUE)
  IF ans="no" THEN 
    CALL display_full(FALSE,FALSE)
  END IF
  CALL savelines()
  RETURN NULL
END FUNCTION

FUNCTION open_load(tmpname,cname)
  DEFINE tmpname,cname STRING
  IF NOT file_read(cname) THEN
    CALL restorelines()
    CALL fgl_winmessage(S_ERROR,sfmt("Can't read:%1",cname),IMG_ERROR)
    LET cname=NULL
  ELSE
    CALL resetNewFile()
    LET m_lastCRC=NULL
    CALL savelines()
    LET tmpname = setCurrFile(cname,tmpname)
    CALL display_full(FALSE,FALSE)
  END IF
  IF NOT isPERFile(tmpname) THEN
    CALL setPreviewActionActive(FALSE)
  END IF
  CALL hideOrShowPreview()
  RETURN tmpname,cname
END FUNCTION

FUNCTION open_finish(tmpname,cname)
  DEFINE tmpname,cname STRING
  --note we compile unconditinally because the buffers may have changed
  CALL compileTmp(tmpname,cname IS NOT NULL)
  CALL flush_cm()
  RETURN tmpname
END FUNCTION

FUNCTION doOpen(tmpname,cname)
  DEFINE tmpname,cname,oldname STRING
  LET oldname=open_prepare(tmpname)
  IF oldname IS NOT NULL THEN
    RETURN oldname
  END IF
  IF cname IS NULL THEN
    LET cname = fglped_filedlg()
  END IF
  IF cname IS NOT NULL THEN
    CALL open_load(tmpname,cname) RETURNING tmpname,cname
  END IF
  RETURN open_finish(tmpname,cname)
END FUNCTION

FUNCTION browse_demos(tmpname)
  DEFINE tmpname,cname,oldname STRING
  LET oldname=open_prepare(tmpname)
  IF oldname IS NOT NULL THEN
    RETURN oldname
  END IF
  LET cname=run_demos()
  IF cname IS NOT NULL THEN
    CALL open_load(tmpname,cname) RETURNING tmpname,cname
    LET m_cmRec.cmCommand="reload"
  END IF
  RETURN open_finish(tmpname,cname)
END FUNCTION

FUNCTION run_demos()
  DEFINE cmd,dir,fulldir,cmdemo,home,tmp,line,lastline,cname STRING
  DEFINE code INT
  DEFINE ch base.Channel
  LET dir=os.Path.dirname(my_arg_val(0))
  LET fulldir=os.Path.fullPath(dir)
  LET cmdemo=myjoin(fulldir,"cmdemo.42m")
  {
  LET home=fgl_getenv("CMHOME")
  IF home IS NULL THEN
    LET home=os.Path.join(dir,"home")
  END IF
  IF NOT os.Path.exists(home) AND NOT os.Path.isDirectory(home) THEN
    MESSAGE sfmt("Can't find fiddle home:%1",home)
    RETURN NULL
  END IF
  IF NOT os.Path.fullPath(os.Path.pwd())==os.Path.fullPath(home) THEN
    LET cmd="cd ",home,"&&"
  END IF
  }
  LET home=fgl_getenv("FGLDIR")
  IF home IS NULL THEN
    MESSAGE "Can't find FGLDIR"
    RETURN NULL
  END IF
  LET home=os.Path.join(home,"demo")
  IF NOT os.Path.exists(home) AND NOT os.Path.isDirectory(home) THEN
    MESSAGE sfmt("Can't find fiddle home:%1",home)
    RETURN NULL
  END IF
  IF NOT os.Path.fullPath(os.Path.pwd())==os.Path.fullPath(home) THEN
    LET cmd="cd ",home,"&&"
  END IF
  LET tmp=os.Path.makeTempName()
  LET cmd=cmd,"fglrun ",cmdemo," >",tmp," 2>&1"
  DISPLAY "Run demo:",cmd
  RUN cmd RETURNING code
  IF code==0 THEN
    LET ch=base.Channel.create()
    TRY
      CALL ch.openFile(tmp,"r")
      WHILE (line:=ch.readLine()) IS NOT NULL
        DISPLAY "line:",line
        LET lastline=line
      END WHILE
      CALL ch.close()
      IF lastline.getIndexOf("COPY2FIDDLE:",1)<>1 THEN
        CALL myERROR("Can't find COPY2FIDDLE")
      ELSE
        LET cname=lastline.subString(13,lastline.getLength())
        DISPLAY "!!!cname:",cname
      END IF
    CATCH
      CALL myERROR(sfmt("read failed:%1",err_get(status)))
    END TRY
  ELSE
    CALL myERROR(sfmt("Returned with code:%1",code))
    RUN "cat "||tmp
  END IF
  CALL os.Path.delete(tmp) RETURNING code
  RETURN cname
END FUNCTION

FUNCTION compileTmp(tmpname,jump_to_error)
  DEFINE tmpname,compmess STRING
  DEFINE jump_to_error BOOLEAN
  IF is4GLOrPerFile(tmpname) THEN
    LET compmess = saveAndCompile(tmpname,jump_to_error)
    IF compmess IS NULL THEN
      CALL mymessage("Compile ok")
      IF isGBC() AND isPERFile(tmpname) AND getSessionId() IS NOT NULL THEN
        CALL livePreview(tmpname)
      END IF
    END IF
  END IF
END FUNCTION

FUNCTION getLiveURL(prog,arg)
  DEFINE prog,arg STRING
  DEFINE dirname,base STRING
  DEFINE questpos INT
  LET base=fgl_getenv("FGL_VMPROXY_START_URL") --https://fglfiddle.com:443/gas/ua/r/cm
  DISPLAY "base:",base,",m_locationhref:",m_locationhref
  IF base IS NOT NULL THEN
        --https://fglfiddle.com:443/gas/ua/r/_fglcm_preview
    RETURN myjoin(os.Path.dirName(base),sfmt("%1?Arg=%2",prog,arg)) 

  END IF
    --http://localhost:6395/gwc-js/index.html?app=_cm
  LET base=fgl_getenv("FGL_WEBSERVER_HTTP_REFERER") 
  IF base IS NOT NULL THEN
    LET questpos=base.getIndexOf("?",1)
    IF questpos>0 THEN
      LET base=base.subString(1,questpos-1)
      RETURN sfmt("%1?app=%2&Arg=%3",base,prog,arg)
    END IF
  END IF
  IF m_locationhref IS NOT NULL THEN
    LET base=m_locationhref
    WHILE (dirname:=os.Path.dirName(base)) IS NOT NULL 
          AND dirname<>"." AND os.Path.baseName(dirname)<>"ua"
      LET base=dirname
      DISPLAY "base:",base
    END WHILE
    RETURN myjoin(myjoin(dirname,"r"),sfmt("%1&Arg=%2",prog,arg))
  END IF
  RETURN "."
END FUNCTION

FUNCTION checkAppDataXCF()
  DEFINE gaspub,gasappdatadir STRING
  LET gaspub=fgl_getenv("GAS_PUBLIC_DIR")
  IF gaspub IS NULL THEN
    RETURN
  END IF
  LET gasappdatadir=mydir(gaspub)
  LET gasappdatadir=myjoin(gasappdatadir,"app")
  DISPLAY "gaspub:",gaspub,",gasappdatadir:", gasappdatadir
  CALL writeXCF(gasappdatadir,"fglcm_webpreview")
  CALL writeXCF(gasappdatadir,"spex")
END FUNCTION

FUNCTION writeXCF(gasappdatadir,appname)
  DEFINE gasappdatadir,appname STRING
  DEFINE xcfname,xcfcontent STRING
  DEFINE c base.Channel
  LET xcfname=myjoin(gasappdatadir,appname||".xcf")
  IF os.Path.exists(xcfname) THEN
    RETURN
  END IF
  LET xcfcontent=sfmt(
    '<?xml version="1.0"?>\n'||
    '<APPLICATION Parent="defaultgwc" '||
    '    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '||
    '    xsi:noNamespaceSchemaLocation="http://www.4js.com/ns/gas/2.30/cfextwa.xsd">\n'||
    '  <EXECUTION AllowUrlParameters="TRUE">\n'||
    '    <PATH>%1</PATH>\n'||
    '    <MODULE>%2</MODULE>\n'||
    '  </EXECUTION>\n'||
    '</APPLICATION>' ,mydir(my_arg_val(0)),appname)
  LET c=base.Channel.create()
  TRY
    CALL c.openFile(xcfname,"w")
  CATCH
    DISPLAY "Can't open xcf:",xcfname
    RETURN
  END TRY
  CALL c.writeLine(xcfcontent)
  CALL c.close()
  DISPLAY "Did write XCF:",xcfname,",with Content:",xcfcontent
END FUNCTION

FUNCTION livePreview(tmpname)
  DEFINE tmpname STRING
  DEFINE liveurl STRING
  CALL copyTmp2Session42f(tmpname)
  CALL checkAppDataXCF()
  LET liveurl=getLiveURL("fglcm_webpreview",util.Strings.urlEncode(getSessionId()))
  #LET liveurl=myjoin(base,util.Strings.urlEncode(sfmt("_fglcm_webpreview?Arg=%1",dirname)))
  #LET liveurl=myjoin(base,sfmt("_fglcm_webpreview?Arg=%1",util.Strings.urlEncode(real42f)))
  DISPLAY "liveurl:",liveurl
  DISPLAY liveurl TO webpreview
  LET m_extURL=getLiveURL("spex",util.Strings.urlEncode(getSessionId()))
END FUNCTION

FUNCTION runprog(tmpname)
  DEFINE tmpname STRING
  DEFINE srcname,cmdir,cmd,info,tmp42m,dummy,line STRING
  DEFINE c base.Channel
  DEFINE code INT

  CALL compileAllForms(IIF(m_IsFiddle,os.Path.pwd(),os.Path.dirname(tmpname)))
  IF (m_lastCompiledPER==tmpname) THEN 
    --need to cp the current tmp 42f fo the real 42f
    CALL copyTmp2Real42f(tmpname) RETURNING dummy
  END IF
  IF m_IsFiddle THEN
    LET srcname=".@main.4gl"
  ELSE
    LET srcname=m_lastCompiled4GL
  END IF
  LET tmp42m=srcname.subString(1,srcname.getLength()-4)
  LET cmdir=mydir(my_arg_val(0))
  IF m_IsFiddle THEN
    LET cmd=myjoin(cmdir,"startfglrun.sh")," ",os.Path.pwd()," ",tmp42m,".42m >result.out 2>&1"
  ELSE
    LET cmd=sfmt("fglrun %1 >result.out 2>&1",tmp42m)
  END IF
  RUN cmd RETURNING code
  LET info=sfmt("Returned code from %1: %2\n",tmp42m,code)
  LET c=base.Channel.create()
  TRY
    CALL c.openFile("result.out","r")
    WHILE (line:=c.readLine()) IS NOT NULL
      IF line=="fglrun sandbox enabled" THEN
        CONTINUE WHILE
      END IF
      LET code=-1
      LET info=info,line,"\n"
    END WHILE
    CALL c.close()
  CATCH
    LET code=256
    LET info=info,sfmt("Failed to read result.txt:%1",err_get(status))
  END TRY
  IF code<>0 THEN
    OPEN WINDOW output WITH FORM "fglcm_output"
    DISPLAY info TO info
    MENU 
      ON ACTION cancel ATTRIBUTE(TEXT="Close")
        EXIT MENU
    END MENU
    CLOSE WINDOW output
  ELSE
    CALL mymessage("Program ended with success and no output")
  END IF
END FUNCTION

FUNCTION to42f(pername)
  DEFINE pername STRING
  RETURN pername.subString(1,pername.getLength()-4)||".42f"
END FUNCTION

FUNCTION compileAllForms(dirpath)
  DEFINE dirpath STRING
  DEFINE dh,code INTEGER
  DEFINE fname, name42f,cmd STRING
  DEFINE mtper,mt42f DATETIME YEAR TO SECOND
  LET dh = os.Path.diropen(dirpath)
  IF dh == 0 THEN 
    DISPLAY "Can't open directory:",dirpath
    RETURN
  END IF
  WHILE TRUE
      LET fname = os.Path.dirnext(dh)
      IF fname IS NULL THEN 
        EXIT WHILE 
      END IF
      IF NOT isPERFile(fname) THEN
         CONTINUE WHILE
      END IF
      LET fname=os.Path.join(dirpath,fname)
      IF os.Path.isDirectory(fname) THEN
        CONTINUE WHILE
      END IF
      LET name42f = to42f(fname)
      IF os.Path.exists(name42f) THEN
        LET mtper=os.Path.mtime(fname)
        LET mt42f=os.Path.mtime(name42f)
        DISPLAY sfmt("%1 mtper:%2,mt42f:%3",fname,mtper,mt42f)
        IF mt42f>=mtper THEN
          DISPLAY sfmt("%1 already compiled",fname)
          CONTINUE WHILE
        END IF
      END IF
      LET cmd=buildCompileCmd(dirpath,"fglform","",fname)  
      LET cmd=cmd,"&1"
      RUN cmd RETURNING code
      IF code THEN
        DISPLAY "Can't compile:",fname
      ELSE
        DISPLAY "Compiled:",fname
      END IF
  END WHILE
  CALL os.Path.dirclose(dh)
END FUNCTION

FUNCTION copyTmp2Real42f(tmpname)
  DEFINE tmpname STRING
  DEFINE tmp42f,tmp42fLast,real42f STRING
  DEFINE code INT
  LET tmp42f=to42f(tmpname)
  LET tmp42fLast=os.Path.baseName(tmp42f)
  LET real42f=myjoin(os.Path.dirName(tmp42f),tmp42fLast.subString(3,tmp42fLast.getLength()))
  DISPLAY "tmp42f:",tmp42f,",real42f:",real42f
  CALL os.Path.copy(tmp42f,real42f) RETURNING code
  RETURN real42f
END FUNCTION

FUNCTION getSessionId()
  DEFINE sessId STRING
  LET sessId=fgl_getenv("FGL_VMPROXY_SESSION_ID")
  LET sessId=sessId.subString(1,6)
  RETURN sessId
END FUNCTION

FUNCTION getSession42f()
  DEFINE sessionId STRING
  LET sessionId=getSessionId()
  IF sessionId IS NULL THEN
    DISPLAY "No session id"
    RETURN NULL
  END IF
  RETURN sfmt("/tmp/fglcm_%1.42f",sessionId)
END FUNCTION

--we delete webcomponents componentType attribute if we
--encounter webcomponents otherwise the whole GBC dies
FUNCTION copyDocWithoutComponentType(src,dest)
  DEFINE src,dest STRING
  DEFINE doc om.DomDocument
  DEFINE rootNode,node om.DomNode
  DEFINE nl om.NodeList
  DEFINE txt STRING
  DEFINE i INT
  LET doc=om.DomDocument.createFromXmlFile(src)
  IF doc IS NULL THEN
    RETURN
  END IF
  LET rootNode=doc.getDocumentElement()
  LET nl = rootNode.selectByPath("//WebComponent")
  FOR i=1 TO nl.getLength()
    LET node=nl.item(i)
    CALL node.removeAttribute("componentType")
  END FOR
  LET txt=rootNode.getAttribute("text")
  IF txt IS NULL THEN
    CALL rootNode.setAttribute("text","<No text>")
  END IF
  CALL rootNode.writeXml(dest)
END FUNCTION

FUNCTION copyTmp2Session42f(tmpname)
  DEFINE tmpname STRING
  DEFINE tmp42f,session42f STRING
  LET tmp42f=tmpname.subString(1,tmpname.getLength()-4),".42f"
  LET session42f=getSession42f()
  IF session42f IS NOT NULL THEN
    --CALL os.Path.copy(tmp42f,session42f) RETURNING code
    CALL copyDocWithoutComponentType(tmp42f,session42f)
  END IF
END FUNCTION

FUNCTION preview_form()
  DEFINE tmp42f STRING
  LET tmp42f=m_lastCompiledPER
  LET tmp42f=tmp42f.subString(1,tmp42f.getLength()-4),".42f"
  CALL showform(tmp42f)
END FUNCTION

FUNCTION show_previewurl()
  OPEN WINDOW previewurl WITH FORM "fglcm_previewurl"
  DISPLAY m_extURL TO previewurl
  MENU
    ON ACTION close
      EXIT MENU
  END MENU
  CLOSE WINDOW previewurl
END FUNCTION

FUNCTION showform(ff)
  DEFINE ff STRING
  OPEN WINDOW sc AT 0,0 WITH 25 ROWS, 60 COLUMNS ATTRIBUTES(STYLE="preview")
  OPEN FORM theform FROM ff
  DISPLAY FORM theform
  MENU "Preview"
    ON ACTION myclose ATTRIBUTE(TEXT="Close (Escape)",ACCELERATOR="Escape")
      EXIT MENU
  END MENU
  CLOSE WINDOW sc
END FUNCTION

FUNCTION mymessage(msg)
  DEFINE msg STRING
  IF NOT m_mainFormOpen THEN
    RETURN
  END IF
  DISPLAY msg TO info
  {
  IF ui.Interface.getFrontEndName()=="GBC" THEN
    --TODO
    --the message block overlaps the editor with larger messages
    RETURN
  END IF
  MESSAGE msg -- in GDC this message sometimes causes black flicker
  }
END FUNCTION

FUNCTION fcsync() --called if our topmenu fired an action
  --we do not use the new 3.10 onFlush Webco mechanism because we want to use
  --the 3.00 GDC too, so we have to explicitly flush the component 
  --the drawback: this costs an additional client server round trip
  DEFINE newVal STRING
  IF NOT m_InitSeen THEN
    DISPLAY "fcsync:no init seen yet"
    RETURN
  END IF
  CALL ui.Interface.frontCall("webcomponent","call",["formonly.cm","fcsync"],[newVal])
  CALL syncInt(newVal)
END FUNCTION

FUNCTION sync() --called if the webco fired an action
  CALL syncInt(fgl_dialog_getbuffer())
END FUNCTION

FUNCTION syncInt(newVal)
  DEFINE newVal,line STRING
  DEFINE orgnum,idx,i,j,z,len,insertpos INT
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
  LET m_locationhref=cmRec.locationhref
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
    --DISPLAY sfmt("delete lines:%1-%2",idx,idx+len-1)
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
  { --we do not use the internal crc: its too slow !
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
  DEFINE flushTimeout INT
  LET m_cmdIdx=m_cmdIdx+1
  LET m_cmRec.cmdIdx=m_cmdIdx
  LET m_cmRec.vm=TRUE
  LET flushTimeout=fgl_getenv("FGLCM_FLUSHTIMEOUT")
  DISPLAY "flushTiout is:",flushTimeout
  LET m_cmRec.flushTimeout=IIF((flushTimeout IS NULL) OR flushTimeout=="0",1000,flushTimeout)
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
  IF m_IsNewFile THEN
    LET m_cmRec.fileName=sfmt("newfile%1.%2",m_cmdIdx,m_NewFileExt)
    LET m_cmRec.extension=m_NewFileExt
  ELSE
    LET ext=os.Path.extension(m_srcfile)
    LET basename=os.Path.baseName(m_srcfile)
    CASE 
      WHEN ext.getLength()>0 
        LET m_cmRec.extension=ext
      WHEN basename.toLowerCase()=="makefile"
        LET m_cmRec.extension="makefile"
    END CASE
  END IF
  DISPLAY "display_full:",m_srcfile,",ext:",m_cmRec.extension,",basename:",basename
  CALL flush_when(flush)
  LET m_lastCRC=NULL
END FUNCTION

FUNCTION setActionActive(name,active)
  DEFINE name STRING
  DEFINE active BOOLEAN
  DEFINE d ui.Dialog
  LET d=ui.Dialog.getCurrent()
  CALL d.setActionActive(name,active)
END FUNCTION

FUNCTION compile_and_process(fname,jump_to_error)
  DEFINE fname STRING
  DEFINE jump_to_error BOOLEAN
  DEFINE compmess STRING
  LET compmess=compile_source(fname,0)
  IF compmess IS NOT NULL THEN
    CALL process_compile_errors(fname,jump_to_error)
  END IF
  RETURN compmess
END FUNCTION

FUNCTION saveAndCompile(fname,jump_to_error)
  DEFINE fname STRING
  DEFINE jump_to_error BOOLEAN
  DEFINE compmess STRING
  IF file_write(fname,TRUE) THEN
    LET compmess=compile_and_process(fname,jump_to_error)
  ELSE 
    LET m_error_line=sfmt("Can't write to:%1",fname)
    CALL fgl_winmessage(S_ERROR,m_error_line,IMG_ERROR)
  END IF
  RETURN compmess
END FUNCTION

FUNCTION buildCompileCmd(dirname,compOrForm,cparam,fname)
  DEFINE dirname,compOrForm,cparam,fname STRING
  DEFINE cmd,baseName STRING
  DISPLAY "buildCompileCmd dirname:",dirname
  LET baseName=os.Path.baseName(fname)
  --we cd into the directory of the source
  IF file_on_windows() THEN
    LET cmd=sfmt("cd \"%1\" && %2 %3 -M -Wall %4 2>",
            dirname,compOrForm,cparam,baseName)
  ELSE
    LET cmd=sfmt("cd \"%1\" && %2 %3 -M -Wall \"%4\" 2>",
            dirname,compOrForm,cparam,baseName)
  END IF
  RETURN cmd
END FUNCTION

FUNCTION regularFromTmpName(tmpname)
  DEFINE tmpname,srcname STRING
  DEFINE atidx INT
  IF (atidx:=tmpname.getIndexOf(".@",1))>0 THEN
    LET srcname=tmpname.subString(1,atidx-1),
                tmpname.subString(atidx+2,tmpname.getLength())
    RETURN srcname
  END IF
  RETURN tmpname
END FUNCTION

FUNCTION compile_source(fname,proposals)
  DEFINE fname STRING
  DEFINE proposals INT
  DEFINE dirname,cmd,cmd1,mess,cparam,line,srcname,compOrForm,tmpName STRING
  DEFINE result STRING
  DEFINE code,i,dummy INT
  DEFINE isPER BOOLEAN
  LET dirname=mydir(fname)
  LET isPER=isPERFile(fname)
  IF isPER THEN
    LET cparam="-c"
  END IF
  IF proposals THEN
    LET cparam="-L"
  END IF
  IF isPER OR proposals THEN
    LET cparam=sfmt("%1 %2,%3",cparam,m_cline,m_ccol)
  ELSE
    IF NOT isPER THEN
      LET cparam="-r"
    END IF
  END IF
  LET compOrForm=IIF(isPER,"fglform","fglcomp")
  LET cmd=buildCompileCmd(dirname,compOrForm,cparam,fname)
  CALL compile_arr.clear()
  DISPLAY "cmd=",cmd
  IF proposals THEN
    --DISPLAY "cmd=",cmd
  END IF
  IF NOT proposals THEN
    LET tmpName=os.Path.makeTempName()
    LET cmd1=cmd,tmpName
    RUN cmd1 RETURNING code 
    IF isPER THEN
      CALL setPreviewActionActive(code==0)
      LET m_lastCompiledPER=IIF(code==0,fname,NULL)
    ELSE
      CALL setActionActive("run",code==0)
      LET m_lastCompiled4GL=IIF(code==0,fname,NULL)
    END IF
    IF NOT code AND os.Path.size(tmpName) > 0 THEN
      LET code=400 --warnings occured
    END IF
  END IF
  IF code OR proposals THEN
    IF proposals THEN
      LET cmd=cmd,"&1"
      CALL file_get_output(cmd,compile_arr)
    ELSE
      CALL file_read_in_arr(tmpName,compile_arr)
      RUN "cat "||tmpName
    END IF
    LET srcname=regularFromTmpName(fname)
    --DISPLAY "srcname=",srcname
    LET mess="compiling of '",srcname,"' failed:\n"
    FOR i=1 TO compile_arr.getLength()
      LET line=compile_arr[i]
      IF line.getIndexOf(".@",1)>0 THEN
        LET compile_arr[i]=regularFromTmpName(line)
      END IF
      LET mess=mess,compile_arr[i],"\n"
    END FOR
    LET result=mess
  END IF
  IF tmpName IS NOT NULL THEN
    DISPLAY "delete tmpName:",tmpName
    CALL os.Path.delete(tmpName) RETURNING dummy
  END IF
  RETURN result
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

FUNCTION myERROR(errstr)
  DEFINE errstr STRING
  ERROR errstr
  DISPLAY "ERROR:",errstr
END FUNCTION

FUNCTION setModified() 
  IF NOT m_modified THEN
    DISPLAY "setModified() TRUE"
    LET m_modified=TRUE
  END IF
END FUNCTION

FUNCTION checkChangedArray()
  DEFINE savelen,len,i INT
  IF m_modified==FALSE THEN
    --DISPLAY "checkChangedArray() no mod"
    RETURN FALSE
  END IF
  LET savelen=m_savedlines.getLength()
  LET len=m_orglines.getLength()
  IF savelen<>len THEN
    --DISPLAY SFMT("savelen:%1 len:%2",savelen,len)
    RETURN TRUE
  END IF
  FOR i=1 TO len
    IF checkChanged(m_savedlines[i],m_orglines[i].line) THEN
      --DISPLAY sfmt("line:%1 differs '%2'<>'%3'",i,m_savedlines[i],m_orglines[i].line)
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

FUNCTION my_write(fname,internal)
  DEFINE fname STRING
  DEFINE internal BOOLEAN
  IF NOT file_write(fname,internal) THEN
    CALL fgl_winmessage(S_ERROR,sfmt("Can't write to:%1",fname),IMG_ERROR)
    RETURN FALSE
  END IF
  DISPLAY "did write to:",fname
  RETURN TRUE
END FUNCTION


--collects the errors and jumps to the first one optionally
FUNCTION process_compile_errors(fname,jump_to_error)
  DEFINE fname STRING
  DEFINE jump_to_error INT
  DEFINE idx,erridx INT
  DEFINE first BOOLEAN
  DEFINE firstcolon,secondcolon,thirdcolon,fourthcolon,fifthcolon,linenum,start INT
  DEFINE line,col,col2,linenumstr,line2numstr,errfile,regular STRING
  DEFINE isError BOOLEAN
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
    IF (firstcolon:=line.getIndexOf(":",start))>0 AND 
      ( (isError:=(line.getIndexOf(":error:",1)<>0)==TRUE) OR line.getIndexOf(":warning:",1)<>0 ) THEN
      LET errfile=line.subString(1,firstcolon-1)
      LET regular=regularFromTmpName(fname)
      IF os.Path.baseName(errfile)<>os.Path.baseName(regular) THEN
        DISPLAY "errfile:",errfile,",regular:",regular
        DISPLAY "do not report warnings in other files yet to fglcm.js"
        LET idx=idx+1
        CONTINUE WHILE
      END IF
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
          LET m_cmRec.annotations[erridx].severity=IIF(isError,"error","warning")
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

FUNCTION file_read_in_arr(txtfile,arr)
  DEFINE txtfile STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE line STRING
  DEFINE ch base.Channel
  LET  ch=base.channel.create()
  CALL arr.clear()
  TRY
  CALL ch.openFile(txtfile,"r")
  IF status == 0 THEN
    WHILE NOT ch.isEof()
      LET line=ch.readLine()
      LET arr[arr.getLength()+1]=line
    END WHILE
    CALL ch.close()
  END IF
  --DISPLAY "m_orglines:",util.JSON.stringify(m_orglines),",len:",m_orglines.getLength()
  CATCH
    DISPLAY err_get(status)
  END TRY
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

FUNCTION file_write_int(srcfile,mode,internal)
  DEFINE srcfile STRING
  DEFINE mode STRING
  DEFINE internal BOOLEAN
  DEFINE ch base.Channel
  DEFINE result,mystatus INT
  DEFINE idx,len INT
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
      IF idx<>len OR NOT internal THEN
        --DISPLAY sfmt("writeLine %1 '%2'",idx,m_orglines[idx].line)
        CALL ch.writeLine(m_orglines[idx].line)
      ELSE
        --internal and last line: avoid the newline problem
        LET line=m_orglines[idx].line
        DISPLAY sfmt("write last line %1 '%2'",idx,line)
        CALL ch.writeNoNL(line)
      END IF
    END FOR
    LET result=TRUE
    CALL ch.close()
  END IF
  RETURN result
END FUNCTION

FUNCTION file_write(srcfile,internal)
  DEFINE srcfile STRING
  DEFINE internal BOOLEAN
  DEFINE start DATETIME YEAR TO FRACTION(2)
  DEFINE result INT
  LET start=CURRENT
  LET result=file_write_int(srcfile,"w",internal)
  DISPLAY "time for file_write:",CURRENT-start,",m_lastCRC:",m_lastCRC
  IF internal AND m_lastCRC IS NOT NULL AND 
      ( m_CRCProg IS NOT NULL OR file_on_mac() ) THEN
    LET start=CURRENT
    CALL checkCRCSum(srcfile)
    DISPLAY "time for cksum:",CURRENT-start,",crc32:",m_cmRec.crc
  END IF
  RETURN result
END FUNCTION

FUNCTION getCRCSum(fname)
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
  RETURN first
END FUNCTION

--should be only called in the accident case
--eats a full network roundtrip due to the frontcall
FUNCTION getFullTextAndRepair(fname)
  DEFINE fname STRING
  DEFINE r RECORD
    full STRING,
    crc32 BIGINT
  END RECORD
  DEFINE ret STRING
  DEFINE crc BIGINT
  DEFINE ch base.Channel
  LET m_LastCRC=NULL
  CALL ui.Interface.frontCall("webcomponent","call",["formonly.cm","getFullTextAndRepair"],[ret])
  CALL util.JSON.parse(ret,r)
  LET ch=base.Channel.create()
  CALL ch.setDelimiter("")
  CALL ch.openFile(fname,"w")
  CALL ch.writeNoNL(r.full) 
  CALL ch.close()
  LET crc=getCRCSum(fname)
  IF crc<>r.crc32 THEN
    DISPLAY "full:"
    DISPLAY "'",r.full,"\n'"
    DISPLAY "file:"
    RUN "cat '"||fname
    DISPLAY "'"
    CALL err(sfmt("crc cksum %1 != crc codemirror %2",crc,r.crc32))
  END IF
  CALL split_src(r.full)
  DISPLAY "lines:",m_orglines.getLength(),",last:",m_orglines[m_orglines.getLength()].line
END FUNCTION

FUNCTION checkCRCSum(fname)
  DEFINE fname STRING
  DEFINE crc BIGINT
  LET crc=getCRCSum(fname)
  IF crc<>m_lastCRC THEN
    RUN "cat "||fname
    DISPLAY (sfmt("!!!!!!crc cksum %1 == crc codemirror %2",crc,m_lastCRC))
    --CALL err(sfmt("!!!!!!crc cksum %1 == crc codemirror %2",crc,m_lastCRC))
    --last resort:we fetch the whole editor content to repair the accident
    CALL getFullTextAndRepair(fname)
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
    IF (ans:=fgl_winquestion("fglcm",sfmt("Save changes to %1?",m_title),
         "yes","yes|no|cancel","question",0))="yes" 
    THEN
      IF isNewFile() THEN
        LET m_srcfile=fglped_saveasdlg(m_srcfile)
        IF m_srcfile IS NULL THEN
          RETURN S_CANCEL
        END IF
      END IF
      CALL my_write(m_srcfile,FALSE) RETURNING dummy
      IF m_IsNewFile THEN
        CALL mysetTitle()
        CALL resetNewFile()
      END IF
    END IF
  END IF
  RETURN ans
END FUNCTION

FUNCTION file_new(ext)
  DEFINE ext STRING
  DEFINE cancel BOOLEAN
  DEFINE t TEXT
  IF ext IS NULL THEN
    OPEN WINDOW file_new WITH FORM "fglcm_filenew" ATTRIBUTE(TEXT="Please choose a File type")
    MENU 
     ON ACTION b4gl ATTRIBUTE(ACCELERATOR="g")
       LET ext="4gl" 
       EXIT MENU
     ON ACTION bper ATTRIBUTE(ACCELERATOR="f")
       LET ext="per" 
       EXIT MENU
     ON ACTION b4st ATTRIBUTE(ACCELERATOR="s")
       LET ext="4st" 
       EXIT MENU
     ON ACTION cancel 
       LET cancel=TRUE 
       EXIT MENU
    END MENU   
    CLOSE WINDOW file_new
    IF cancel THEN
      RETURN S_CANCEL
    END IF
  END IF
  CALL m_orglines.clear()
  LET m_orglines[1].line=" " CLIPPED
  LET m_orglines[1].orgnum=1
  CASE ext
    WHEN "per"
      LET m_orglines[1].line="LAYOUT" LET m_orglines[1].orgnum=1
      LET m_orglines[2].line="GRID"   LET m_orglines[2].orgnum=2
      LET m_orglines[3].line="{"      LET m_orglines[3].orgnum=3
      LET m_orglines[4].line="X"      LET m_orglines[4].orgnum=4
      LET m_orglines[5].line="}"      LET m_orglines[5].orgnum=5      
      LET m_orglines[6].line="END"    LET m_orglines[6].orgnum=6      
    WHEN "4st"
      LOCATE t IN FILE myjoin(myjoin(fgl_getenv("FGLDIR"),"lib"),"default.4st")
      CALL split_src(t)
  END CASE
  LET m_IsNewFile = TRUE
  LET m_NewFileExt=ext
  CALL savelines()
  CALL mymessage(sfmt("New file with extension:%1",ext))
  RETURN ext
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
  IF fname IS NULL THEN
    LET tmpname=".@__empty__.",m_NewFileExt
  ELSE
    LET dir=mydir(fname)
    LET shortname=os.Path.basename(fname)
    LET tmpname=myjoin(dir,sfmt(".@%1",shortname))
  END IF
  RETURN tmpname
END FUNCTION

--returns true if the current contents was initialized by File->New
--or File->New From Wizard
FUNCTION isNewFile()
  RETURN (m_srcfile IS NULL)  OR m_IsNewFile
END FUNCTION

FUNCTION resetNewFile()
  LET m_isNewFile=NULL
  LET m_NewFileExt=NULL
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
  CALL fgl_setTitle(sfmt("%1 - fglcm",m_title))
END FUNCTION

FUNCTION fglped_saveasdlg(fname)
  DEFINE fname STRING
  DEFINE filename,ext,newext,lst STRING
  DEFINE r1 FILEDLG_RECORD
  --CALL fgl_winmessage("Info",sfmt("fglped_saveasdlg %1",fname),"info")
  IF m_IsNewFile THEN
    LET ext=m_NewFileExt
  ELSE
    LET ext=os.Path.extension(m_srcfile)
  END IF
  IF _isLocal() THEN
    IF fname IS NULL THEN
      LET fname=os.Path.pwd()
    END IF
    LET lst=IIF(ext IS NULL,"*.*","*."||ext||" *.*")
    CALL ui.Interface.frontCall("standard","saveFile", [fname, "Genero file",lst, "Save File" ], 
       [filename])
  ELSE
    LET r1.title="Please specify disk file name for the current document"
    IF m_IsFiddle THEN
      LET r1.opt_root_dir=os.Path.pwd()
    END IF
    LET r1.types[1].description="Genero ",ext," file"
    LET r1.types[1].suffixes="*.",ext
    LET r1.types[2].description="All files (*.*)"
    LET r1.types[2].suffixes="*.*"
    LET filename= filedlg_save(r1.*)
  END IF
  IF filename IS NULL THEN
    RETURN NULL
  END IF
  DISPLAY "filename:",filename
  LET newext=os.Path.extension(filename)
  IF newext.getLength()==0 AND ext.getLength()>0 THEN
    LET filename=filename,".",ext
  END IF
  --IF os.Path.exists(filename) THEN
  --  IF NOT _filedlg_mbox_yn("Warning",sfmt("File '%1' already exists, do you want to replace it ?",
       --filename),"question") THEN
  --    RETURN NULL
  --  END IF
  --END IF
  RETURN filename
END FUNCTION

{
FUNCTION fglped_filedlg()
  DEFINE filename STRING
  CALL ui.Interface.frontCall("standard","openfile", [os.Path.pwd(), "All Files", "*", "Open File" ], 
    [filename])
  RETURN filename
END FUNCTION
}
FUNCTION fglped_filedlg()
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  IF _isLocal() THEN
    CALL ui.interface.frontCall("standard","openfile",[os.Path.pwd(),"Form Files","*.per",
      "Please choose a form"],[fname])
  ELSE
    LET r1.title="Please choose a file"
    IF m_IsFiddle THEN --sandbox
      LET r1.opt_root_dir=os.Path.pwd()
    END IF
    LET r1.types[1].description="Genero source files (*.4gl,*.per)"
    LET r1.types[1].suffixes="*.4gl|*.per"
    LET r1.types[2].description="Genero resource files (*.4st,*.4ad,*.4tm,*.4sm,*.4tb)"
    LET r1.types[2].suffixes="*.4st|*.4ad|*.4tm|*.4sm|*.4tb"
    LET r1.types[3].description="All files (*.*)"
    LET r1.types[3].suffixes="*.*"
    LET fname= filedlg_open(r1.*)
  END IF
  RETURN fname
END FUNCTION

FUNCTION split_src(src)
  DEFINE src,line STRING
  DEFINE tok base.StringTokenizer
  DEFINE linenum INT
  CALL m_orglines.clear()
  LET tok=base.StringTokenizer.createExt(src,"\n","\\",TRUE)
  LET linenum=1
  WHILE tok.hasMoreTokens()
    LET line=tok.nextToken()
    LET m_orglines[linenum].line=IIF(line IS NULL," " CLIPPED,line)
    LET m_orglines[linenum].orgnum=linenum
    LET linenum=linenum+1
  END WHILE
  LET linenum=m_orglines.getLength()
  IF linenum>1 THEN
    LET line=m_orglines[linenum].line
    IF line.getLength()==0 THEN
      --delete last line containing newline
      CALL m_orglines.deleteElement(linenum)
    END IF
  END IF
END FUNCTION
{
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

--CRC32 algorithm in 4GL
--it does not work for a "char" semantic encoded STRING
FUNCTION crc32int(str)
  DEFINE str,ch STRING
  DEFINE crc,len,i,code,idx,res INT
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
}
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

FUNCTION loadKeywords()
  DEFINE start DATETIME YEAR TO FRACTION(2)
  LET start=CURRENT
  CALL loadKeywordsFor("fgl","4gl")
  CALL loadKeywordsFor("per","per")
  DISPLAY "time for loadKeywords:",CURRENT-start
END FUNCTION

#+ looks up the vim syntax files
#+ pre 3.10: $FGLDIR/lib/fgl.vim|per.vim
#+ since 3.10: $FGLDIR/vimfiles/syntax/fgl.vim|per.vim
FUNCTION loadKeywordsFor(vimmode,mode)
  DEFINE vimmode,mode,vimfile,vimfile2 STRING
  DEFINE sep,fgldir,cmdir,templ STRING
  LET cmdir=mydir(my_arg_val(0))
  LET templ=myjoin(cmdir,sfmt("%1.js",mode))
  LET sep=os.Path.separator()
  LET fgldir=fgl_getenv("FGLDIR")
  IF fgldir IS NULL THEN
    CALL err("FGLDIR must be set")
  END IF
  LET vimfile=myjoin(fgldir,sfmt("vimfiles%1syntax%2%3.vim",sep,sep,vimmode))
  LET vimfile2=myjoin(fgldir,sfmt("lib%1%2.vim",sep,vimmode))
  CASE
    WHEN os.Path.exists(vimfile)
      CALL mergekeywords(cmdir,mode,templ,vimfile)
    WHEN os.Path.exists(vimfile2)
      CALL mergekeywords(cmdir,mode,templ,vimfile2)
    OTHERWISE
      CALL err(sfmt("Can't find neither %1 nor %2 for %3 keywords",vimfile,vimfile2,mode))
  END CASE
END FUNCTION

#+ merges keywords from the vim syntax files
#+ into the codemirror mode template file
FUNCTION mergekeywords(cmdir,mode,templ,vimfile)
  DEFINE cmdir,mode,templ,vimfile STRING
  DEFINE line,keyword,destfile,sep STRING
  DEFINE c,d base.Channel
  DEFINE i INT
  DEFINE keywords DYNAMIC ARRAY OF STRING
  LET sep=os.Path.separator()
  LET c=base.Channel.create()
  CALL c.openFile(vimfile,"r")
  WHILE (line:=c.readLine()) IS NOT NULL
    IF line.getIndexOf("syn keyword fglKeyword ",1)==1 THEN
      LET keyword=line.subString(24,line.getLength())
      LET keywords[keywords.getLength()+1]=keyword.trim()
    END IF
  END WHILE
  CALL c.close()
  IF keywords.getLength() = 0 THEN
    CALL err(sfmt("Didn't find any keywords in vim file:%1",vimfile))
  END IF
  CALL c.openFile(templ,"r")
  LET destfile=myjoin(cmdir,
     sfmt("webcomponents%1fglcm%2customMode%3%4.js",
     sep,sep,sep,mode))
  LET d=base.Channel.create()
  CALL d.openFile(destfile,"w")
  CALL d.writeLine(sfmt("// This file was generated by cm, template: %1",templ))
  CALL d.writeLine(     "// changes to this file have no effect")
  WHILE (line:=c.readLine()) IS NOT NULL
    IF line.getIndexOf("var keywords={};",1)==1 THEN
      CALL d.writeLine(       '    var keywords={')
      CALL d.writeLine(  sfmt('       "%1":true',keywords[1]))
      FOR i=2 TO keywords.getLength()
        CALL d.writeLine(sfmt('      ,"%1":true',keywords[i]))
      END FOR
      CALL d.writeLine('    } //keywords')
    ELSE
      CALL d.writeLine(line)
    END IF
  END WHILE
  CALL c.close()
  CALL d.close()
END FUNCTION
