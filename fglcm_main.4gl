IMPORT os
IMPORT FGL fglcm
IMPORT FGL fglcm_ext
DEFINE starttime DATETIME HOUR TO FRACTION(1)
DEFINE diff INTERVAL MINUTE TO FRACTION(1)
MAIN
  LET starttime=CURRENT
  CALL fglcm.init_args()
  CALL main2(TRUE)
END MAIN

FUNCTION main2(enter_main_loop)
  DEFINE enter_main_loop BOOLEAN
  CALL fglcm.init()
  --CALL fglcm_ext.init() --forces fglcm_ext being loaded
  --CALL ui.Form.setDefaultInitializer("fglcm_ext_form_init")
  IF NOT fglcm.initSrcFile(fglcm.my_arg_val(1)) THEN
    CALL fglcm.deleteLog()
    CALL fglcm.myExit("main2",1)
  END IF
  CALL fglcm.openMainWindow()
  CALL fglcm_ext.initMainWindow()
  IF enter_main_loop THEN
    WHILE edit_source()
      CALL fglcm.displayForm()
      CALL fglcm_ext.initMainWindow()
      CALL fglcm.before_input(NULL,FALSE)
    END WHILE
  END IF
END FUNCTION

--main INPUT of the editor, everything is called from here
PRIVATE FUNCTION edit_source()
  DEFINE log STRING
  OPTIONS INPUT WRAP
  --the actions using fsync() are triggered by TopMenu/Genero Shortcuts
  --the actions using sync() are triggered from the code mirror webcomponent
  INPUT fglcm.m_cm
      WITHOUT DEFAULTS
      FROM cm
      ATTRIBUTE(ACCEPT = FALSE, CANCEL = FALSE)
    BEFORE INPUT
      CALL fglcm.before_input(DIALOG,TRUE)
      CALL DIALOG.setActionActive("preview_toggle_orient","0")

    ON ACTION fglcm_init ATTRIBUTE(DEFAULTVIEW = NO) --invoked by the editor
      CALL fglcm.setInitSeen()
      CALL DIALOG.setActionActive("preview_toggle_orient","1")

    ON ACTION run
      CALL fglcm.sync()
      CALL fglcm.runprog()

    ON ACTION preview
      CALL fglcm.sync() 
      CALL fglcm.preview_form()

    ON ACTION showpreviewurl
      CALL fglcm.show_previewurl()

    ON ACTION close
      CALL fglcm.sync()
      CALL fglcm.doClose(TRUE)

      --ON KEY(TAB)
      --  DISPLAY "!!!TAB!!!"
      --  CALL fglcm.sync()
      --  CALL fglcm.doComplete()
    ON ACTION complete --triggered by WC
      DISPLAY "!!!Complete!!!"
      CALL fglcm.sync()
      CALL fglcm.doComplete()

    ON ACTION find
      CALL fglcm.sync()
      CALL fglcm.doFind()

    ON ACTION replace
      CALL fglcm.sync()
      CALL fglcm.doReplace()

    ON ACTION gotoline
      CALL fglcm.sync()
      CALL fglcm.doGotoLine()

    ON ACTION update ATTRIBUTE(DEFAULTVIEW=NO) --invoked by the editor
      DISPLAY "!!!update!!!"
      CALL fglcm.sync()
      IF NOT fglcm.actionPending() THEN
        CALL fglcm.doCompile(FALSE)
      END IF

    ON ACTION compile ATTRIBUTE(DEFAULTVIEW = NO)
      CALL fglcm.sync()
      CALL fglcm.doCompile(TRUE) --jumps to the first error

    ON ACTION new --triggered by TopMenu
      CALL fglcm.sync()
      CALL fglcm.doFileNew()

    ON ACTION open --triggered by TopMenu
      CALL fglcm.sync()
      CALL fglcm.doFileOpen(NULL)

    ON ACTION open_from_picklist
      CALL fglcm.sync()
      CALL fglcm.openFromPickList()

    ON ACTION save
      CALL fglcm.sync()
      CALL fglcm.doFileSave()

    ON ACTION saveas
      CALL fglcm.sync()
      CALL fglcm.doFileSaveAs()

    ON ACTION format_src
      CALL fglcm.sync()
      CALL fglcm.formatSource()

    ON ACTION show_preview
      CALL fglcm.sync()
      CALL fglcm.hidePreview(FALSE)

    ON ACTION hide_preview
      CALL fglcm.sync()
      CALL fglcm.hidePreview(TRUE)

    ON ACTION preview_toggle_orient
      CALL fglcm.sync()
      CALL fglcm.togglePreviewOrient1()
      DISPLAY "after toggle"
      RETURN TRUE

    ON ACTION urready
      DISPLAY "urready"
      CALL fglcm.initGBC()
      LET diff = CURRENT - starttime
      DISPLAY "diff=",diff


    ON ACTION getlog
      CALL ui.Interface.frontCall(
          "webcomponent", "call", ["formonly.cm", "getLog"], [log])

    ON ACTION fglcm_ext1
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext1")
    ON ACTION fglcm_ext2
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext2")
    ON ACTION fglcm_ext3
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext3")
    ON ACTION fglcm_ext4
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext4")
    ON ACTION fglcm_ext5
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext5")
    ON ACTION fglcm_ext6
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext6")
    ON ACTION fglcm_ext7
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext7")
    ON ACTION fglcm_ext8
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext8")
    ON ACTION fglcm_ext9
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext9")
    ON ACTION fglcm_ext10
      CALL fglcm.sync()
      CALL fglcm_ext.extensionAction("fglcm_ext10")

    ON ACTION main4gl
      CALL fglcm.sync()
      CALL fglcm.doFileOpen("main.4gl")

    ON ACTION mainper
      CALL fglcm.sync()
      CALL fglcm.doFileOpen("main.per")

    ON ACTION browse_demos
      CALL fglcm.sync()
      CALL fglcm.browse_demos()

  END INPUT
  DISPLAY "after end input"
  RETURN FALSE
END FUNCTION
