FUNCTION init()
END FUNCTION

FUNCTION initMainWindow()
END FUNCTION

FUNCTION fglcm_ext_form_init(f)
  DEFINE f ui.Form
  DEFINE n om.DomNode
  --INITIALIZE f TO NULL --silence the warning
  LET n=f.getNode()
  DISPLAY "fglcm_ext_form_init:",n.getAttribute("name")
END FUNCTION

FUNCTION extensionAction(action)
  DEFINE action STRING
  INITIALIZE action TO NULL
END FUNCTION

FUNCTION run()
END FUNCTION

