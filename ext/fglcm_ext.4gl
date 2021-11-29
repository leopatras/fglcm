IMPORT os

CONSTANT TBNAME="fglcm_ext_standard.4tb"
FUNCTION init()
END FUNCTION

PRIVATE FUNCTION extPath(asset)
  DEFINE asset STRING
  DEFINE extDir STRING
  LET extDir=fgl_getenv("FGLCM_EXT_DIR")
  RETURN os.Path.join(extDir,asset)
END FUNCTION

PRIVATE FUNCTION loadTB(f)
  DEFINE f ui.Form
  DEFINE name, tb STRING
  LET name = IIF(fgl_getenv("FGLFIDDLE") IS NOT NULL, "fglfiddle.4tb", TBNAME)
  LET tb = IIF(os.Path.exists(name), name, extPath(name))
  CALL f.loadToolBar(tb)
END FUNCTION

FUNCTION initMainWindow()
  DEFINE win ui.Window
  DEFINE f ui.Form
  LET win=ui.Window.getCurrent()
  LET f=win.getForm()
  CALL loadTB(f)
END FUNCTION

FUNCTION fglcm_ext_form_init(f)
  DEFINE f ui.Form
  DEFINE n om.DomNode
  LET n=f.getNode()
  DISPLAY "fglcm_ext_form_init:",n.getAttribute("name")
END FUNCTION

FUNCTION extensionAction(action)
  DEFINE action STRING
  INITIALIZE action TO NULL
END FUNCTION

FUNCTION run()
END FUNCTION

