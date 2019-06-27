IMPORT os
IMPORT util
IMPORT FGL fglcm
IMPORT FGL fglcm_main
&define QA_ASSERT(x) IF NOT NVL(x,0) THEN CALL fglcm.assert(#x) END IF
&define QA_ASSERT_MSG(x,msg) IF NOT NVL(x,0) THEN CALL fglcm.assert_with_msg(#x,msg) END IF
DEFINE m_main_mod STRING
CONSTANT newfile = "test/_newfile.4gl"
CONSTANT xxfile = "test/xx.4gl"
CONSTANT yyfile = "test/yy.4gl"
CONSTANT miniprog = "MAIN END MAIN"
MAIN
  LET m_main_mod = os.Path.join(os.Path.pwd(), "fglcm_main.42m")
  QA_ASSERT(os.Path.exists(m_main_mod))
  QA_ASSERT(os.Path.exists("fglcm.42m"))
  
  CALL test_new_file_from_arg_1()
  CALL test_new_file_from_arg_1_with_mod()
  CALL test_file_open()

END MAIN

FUNCTION setup_new_file()
  DEFINE args DYNAMIC ARRAY OF STRING
  CALL os.Path.delete(newfile) RETURNING status
  QA_ASSERT(NOT os.Path.exists(newfile))
  QA_ASSERT(fglcm.canWrite(newfile))
  QA_ASSERT(NOT os.Path.exists(newfile))
  LET args[1] = newfile
  CALL fglcm.setArgs(m_main_mod, args)
  CALL fglcm_main.main2(FALSE) --we do not enter the main loop
  QA_ASSERT(fglcm.mygetTitle() == "_newfile.4gl - fglcm [New File]")
  QA_ASSERT(os.Path.exists(newfile))
  QA_ASSERT(os.Path.size(newfile) == 1) --1 newline
END FUNCTION

#+ we call "cm tests/_newfile.4gl"
#+ tests/_newfile.4gl is created, but if no change happens
#+ its deleted when closing
FUNCTION test_new_file_from_arg_1()
  CALL setup_new_file()
  CALL fglcm.doClose(FALSE)
  QA_ASSERT(NOT os.Path.exists(newfile)) --unchanged new file must have been deleted
  CALL fglcm.resetForQA() --reset all vars
END FUNCTION

#+ we call "cm tests/_newfile.4gl"
#+ and insert something from the clipboard
FUNCTION test_new_file_from_arg_1_with_mod()
  DEFINE content STRING
  CALL setup_new_file()
  INPUT fglcm.m_cm
    WITHOUT DEFAULTS
    FROM cm
    ATTRIBUTE(ACCEPT = FALSE, CANCEL = FALSE)
    BEFORE INPUT
      CALL fglcm.before_input(DIALOG, FALSE)
    ON ACTION fglcm_init ATTRIBUTE(DEFAULTVIEW = NO) --invoked by the editor
      DISPLAY "init seen"
      CALL fglcm.setInitSeen()
      CALL fglcm.qaSendInput(miniprog)
    ON ACTION update ATTRIBUTE(DEFAULTVIEW = NO) --invoked by the editor
      DISPLAY "update seen"
      CALL fglcm.sync()
      CALL fglcm.doFileSave()
      EXIT INPUT
      --CALL fglcm.doCompile(FALSE)
    ON ACTION run
  END INPUT
  CALL fglcm.doClose(FALSE)
  CALL fglcm.resetForQA() --reset all vars
  QA_ASSERT(os.Path.exists(newfile)) --changed new file must be there
  LET content = fglcm.qaReadFile(newfile)
  QA_ASSERT(content.equals(sfmt("%1\n", miniprog)))
  CALL os.Path.delete(newfile) RETURNING status
  CALL fglcm.resetForQA() --reset all vars
END FUNCTION

#+ first round: we open a file not terminated by '\n'
#+   and leave it unchanged: it should not be changed/modified
#+ 2nd round: we open a file not terminated by '\n'
#+   and leave it unchanged: choose "File->New" and change to content
#+ 3nd round: we modify the content, no terminating '\n' is added 
#+   in the editor window, but we add one upon saving
FUNCTION test_file_open()
  DEFINE args DYNAMIC ARRAY OF STRING
  DEFINE mTime,content STRING
  DEFINE size INT
  DEFINE i INT
  CALL os.Path.delete(yyfile) RETURNING status
  FOR i = 1 TO 3
    CALL writeStringToFile(xxfile, "MAIN END MAIN")
    LET mTime=os.Path.mtime(xxfile)
    LET size=os.Path.size(xxfile)
    LET args[1] = xxfile
    CALL fglcm.setArgs(m_main_mod, args)
    CALL fglcm_main.main2(FALSE) --we do not enter the main loop
    INPUT fglcm.m_cm
      WITHOUT DEFAULTS
      FROM cm
      ATTRIBUTE(ACCEPT = FALSE, CANCEL = FALSE)
      BEFORE INPUT
        CALL fglcm.before_input(DIALOG, FALSE)
      ON ACTION fglcm_init ATTRIBUTE(DEFAULTVIEW = NO) --invoked by the editor
        DISPLAY "init seen,i:",i
        CALL fglcm.setInitSeen()
        CALL fglcm.doCompile(FALSE)
        CASE i
          WHEN 1 --do nothing
            EXIT INPUT
          WHEN 2 --change content
            CALL fglcm.qaSendInput("MAIN\nEND MAIN") --no terminating '\n'
          WHEN 3 --choose "File New"
            CALL fglcm.fcsync()
            CALL fglcm.qaSendAction("file_new")
        END CASE
      ON ACTION file_new
        CALL fglcm.sync()
        CALL fglcm.qaSetFileNewExt("4gl")
        CALL fglcm.doFileNew()
        QA_ASSERT_MSG(fglcm.mygetTitle() == "Unnamed - fglcm [New File]",sfmt("title:%1",fglcm.mygetTitle()))
        CALL ui.Interface.refresh()
        CALL fglcm.qaSendInput("MAIN\nEND MAIN") --no terminating '\n'
      ON ACTION update ATTRIBUTE(DEFAULTVIEW = NO) --invoked by the editor
        DISPLAY "update seen,value:",fgl_dialog_getbuffer()
        CALL fglcm.sync()
        IF i==3 THEN
          CALL fglcm.qaSetFileSaveAsFileName(yyfile)
        END IF
        CALL fglcm.doFileSave()
        EXIT INPUT
      ON ACTION run
    END INPUT
    CALL fglcm.doClose(FALSE)
    LET content = fglcm.qaReadFile(IIF(i==3,yyfile,xxfile))
    IF i=1 THEN
      QA_ASSERT(mTime.equals(os.Path.mtime(xxfile))) --file must be left unchanged
      QA_ASSERT(size==os.Path.size(xxfile)) 
    ELSE
      QA_ASSERT_MSG(content.equals("MAIN\nEND MAIN\n"),sfmt("i:%1,content:%2",i,util.JSON.stringify(content))) --must have terminating '\n'
    END IF
    CALL fglcm.resetForQA() --reset all vars
  END FOR
END FUNCTION
