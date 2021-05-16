OPTIONS
SHORT CIRCUIT
IMPORT os
MAIN
  DEFINE testdoc om.DomDocument
  DEFINE fname STRING
  DEFINE mt1 DATETIME YEAR TO SECOND
  DEFINE size1 INT
  OPTIONS ON CLOSE APPLICATION CALL myonclose
  LET fname = getSession42f(arg_val(1))
  IF num_args() = 1 THEN
    CALL startSub(fname)
    RETURN
  END IF
  DISPLAY "fname:", fname
  WHILE TRUE
    IF NOT os.Path.exists(fname) THEN
      EXIT PROGRAM 1
    END IF
    LET testdoc = om.DomDocument.createFromXmlFile(fname)
    LET mt1 = os.Path.mtime(fname)
    LET size1 = os.Path.size(fname)
    IF testdoc IS NULL THEN
      DISPLAY "testdoc was not valid"
      OPEN FORM f FROM "fglcm_webpreview_error"
      DISPLAY FORM f
      DISPLAY "Form not valid XML" TO info
      MENU
        BEFORE MENU
          CALL poll(fname, mt1, size1)
          EXIT MENU
      END MENU
    ELSE
      LET testdoc = NULL
      OPEN FORM f FROM fname
      DISPLAY FORM f
      CALL poll(fname, mt1, size1)
    END IF
  END WHILE
END MAIN

FUNCTION myonclose()
  DISPLAY "!!!!!!!!myonclose"
END FUNCTION

FUNCTION startSub(fname)
  DEFINE fname STRING
  DEFINE size1, code INT
  DEFINE mt1 DATETIME YEAR TO SECOND
  DEFINE title STRING
  WHILE TRUE
    --we start ourselves, if we get an error we try again if the file has been changed
    RUN SFMT('fglrun "%1" %2 %3', arg_val(0), arg_val(1), fgl_getpid())
        RETURNING code
    DISPLAY "returned from sub with code:", code
    IF NOT os.Path.exists(fname) OR code == 0 THEN --editor probably died
      EXIT PROGRAM 0
    END IF
    LET mt1 = os.Path.mtime(fname)
    LET size1 = os.Path.size(fname)
    LET title = SFMT("Failed with code:%1", code)
    OPEN FORM f FROM "fglcm_webpreview_error"
    DISPLAY FORM f
    DISPLAY title TO info
    MENU
      BEFORE MENU
        CALL poll(fname, mt1, size1)
        EXIT MENU
    END MENU
  END WHILE
END FUNCTION

FUNCTION poll(fname, mt1, size1)
  DEFINE fname STRING
  DEFINE mt1, mt2 DATETIME YEAR TO SECOND
  DEFINE size1, size2 INT
  CALL ui.Interface.refresh()
  WHILE TRUE
    SLEEP 1
    LET mt2 = os.Path.mtime(fname)
    LET size2 = os.Path.size(fname)
    IF mt2 <> mt1 OR size1 <> size2 OR (NOT os.Path.exists(fname)) THEN
      EXIT WHILE
    END IF
  END WHILE
END FUNCTION

FUNCTION getSession42f(sessionId)
  DEFINE sessionId STRING
  DEFINE fname, dirname STRING
  IF sessionId IS NULL THEN
    EXIT PROGRAM 1
  END IF
  LET fname = SFMT("/tmp/fglcm_%1.42f", sessionId)
  LET dirname = os.Path.dirName(fname)
  IF dirname IS NULL OR dirname <> "/tmp" THEN
    --avoid loading a file with ../.. etc
    EXIT PROGRAM 1
  END IF
  IF NOT os.Path.exists(fname) THEN
    EXIT PROGRAM 1
  END IF
  RETURN fname
END FUNCTION

FUNCTION speedupIdleAction()
  DEFINE w ui.Window
  DEFINE wNode, idleNode om.DomNode
  DEFINE nl om.NodeList
  --as all other clients are disturbed by the idle action we
  --"disable" it by giving it a never ending timeout
  LET w = ui.Window.getCurrent()
  LET wNode = w.getNode()
  LET nl = wNode.selectByPath("//IdleAction[@timeout=\"1\"]")
  IF nl.getLength() != 1 THEN
    RETURN
  END IF
  LET idleNode = nl.item(1)
  --we set a smaller timeout: GBC honors this
  CALL idleNode.setAttribute("timeout", "0.5")
END FUNCTION
