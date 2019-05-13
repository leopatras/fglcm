IMPORT os
IMPORT FGL fglcm
IMPORT FGL fglcm_ext
MAIN
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
    EXIT PROGRAM 1
  END IF
  CALL fglcm.openMainWindow()
  CALL fglcm_ext.initMainWindow()
  IF enter_main_loop THEN
    CALL edit_source()
  END IF
END FUNCTION

--main INPUT of the editor, everything is called from here
PRIVATE FUNCTION edit_source()
  OPTIONS INPUT WRAP
  --the actions using fsync() are triggered by TopMenu/Genero Shortcuts
  --the actions using sync() are triggered from the code mirror webcomponent
  INPUT fglcm.m_cm WITHOUT DEFAULTS FROM cm ATTRIBUTE(accept=FALSE,cancel=FALSE)
    BEFORE INPUT
      CALL fglcm.before_input(DIALOG,TRUE)

    ON ACTION fglcm_init ATTRIBUTE(DEFAULTVIEW=NO) --invoked by the editor
      CALL fglcm.setInitSeen()

    ON ACTION run
      CALL fglcm.runprog()

    ON ACTION preview
      CALL fglcm.preview_form()

    ON ACTION showpreviewurl
      CALL fglcm.show_previewurl()

    ON ACTION close_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL fglcm.sync()
      CALL fglcm.doClose(TRUE)
    ON ACTION close
      CALL fglcm.fcsync()
      CALL fglcm.doClose(TRUE)

    ON ACTION complete --triggered by WC
      CALL fglcm.sync() 
      CALL fglcm.doComplete()

    ON ACTION find
      CALL fglcm.fcsync()
      CALL fglcm.doFind()
      
    ON ACTION replace
      CALL fglcm.fcsync()
      CALL fglcm.doReplace()

    ON ACTION gotoline_cm --triggered by WC
      CALL fglcm.sync()
      CALL fglcm.doGotoLine()
    ON ACTION gotoline --triggered by TopMenu
      CALL fglcm.fcsync()
      CALL fglcm.doGotoLine()

    ON ACTION update ATTRIBUTE(DEFAULTVIEW=NO) --invoked by the editor
      CALL fglcm.sync()
      CALL fglcm.doCompile(FALSE)

    ON ACTION compile ATTRIBUTE(DEFAULTVIEW=NO)
      CALL fglcm.fcsync()
      CALL fglcm.doCompile(TRUE) --jumps to the first error

    ON ACTION new_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL fglcm.sync()
      CALL fglcm.doFileNew()
    ON ACTION new
      CALL fglcm.fcsync()
      CALL fglcm.doFileNew()
      
    ON ACTION open_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL fglcm.sync()
      CALL fglcm.doFileOpen(NULL)
    ON ACTION open
      CALL fglcm.fcsync()
      CALL fglcm.doFileOpen(NULL)

    ON ACTION open_from_picklist
      CALL fglcm.fcsync()
      CALL fglcm.openFromPickList()

    ON ACTION save_cm ATTRIBUTE(DEFAULTVIEW=NO)
      CALL fglcm.sync()
      CALL fglcm.doFileSave()
    ON ACTION save
      CALL fglcm.fcsync()
      CALL fglcm.doFileSave()

    ON ACTION saveas
      CALL fglcm.fcsync()
      CALL fglcm.doFileSaveAs()

    ON ACTION fglcm_ext1
      CALL fglcm.fcsync()
      CALL fglcm_ext.extensionAction("fglcm_ext1")
    ON ACTION fglcm_ext2
      CALL fglcm.fcsync()
      CALL fglcm_ext.extensionAction("fglcm_ext2")
    ON ACTION fglcm_ext3
      CALL fglcm.fcsync()
      CALL fglcm_ext.extensionAction("fglcm_ext3")
    ON ACTION fglcm_ext4
      CALL fglcm.fcsync()
      CALL fglcm_ext.extensionAction("fglcm_ext4")
    ON ACTION fglcm_ext5
      CALL fglcm.fcsync()
      CALL fglcm_ext.extensionAction("fglcm_ext5")

    ON ACTION main4gl
      CALL fglcm.fcsync()
      CALL fglcm.doFileOpen("main.4gl")

    ON ACTION mainper
      CALL fglcm.fcsync()
      CALL fglcm.doFileOpen("main.per")

    ON ACTION browse_demos
      CALL fglcm.fcsync()
      CALL fglcm.browse_demos()

  END INPUT
END FUNCTION
