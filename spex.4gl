#+ (s)tand alone (p)reviewer for (ex)ternal clients
#+ it differs from fglcm_webpreview having an ON IDLE action
#+ and an "Exit" button
#+ the ON IDLE action in fglcm_webpreview is not usable because
#+ of focus problems
OPTIONS
SHORT CIRCUIT
IMPORT os
MAIN
  DEFINE fname STRING
  DEFINE mt1 DATETIME YEAR TO SECOND
  DEFINE size1 INT
  OPTIONS ON CLOSE APPLICATION CALL myonclose
  LET fname = getSession42f(arg_val(1))
  IF NOT os.Path.exists(fname) THEN
    EXIT PROGRAM 1
  END IF
  DISPLAY "fname:", fname
  WHILE TRUE
    IF (NOT os.Path.exists(fname)) OR isInvalid(fname) THEN
      DISPLAY "testdoc was not valid"
      OPEN FORM f FROM "fglcm_webpreview_error"
      DISPLAY FORM f
      DISPLAY IIF(NOT os.Path.exists(fname),
              "No Form.",
              "Form is not valid XML.")
          TO info
      MENU
        --Poll every second for a change on the server side
        --Note: I would really love to have a pending long poll GET with an app
        --sitting on the device (in case of GMI/GMA) instead of bombing the server this way
        ON IDLE 1
          IF NOT os.Path.exists(fname) THEN
            DISPLAY "No Form." TO info
            CONTINUE MENU
          END IF
          IF isInvalid(fname) THEN
            DISPLAY "Form is not valid XML." TO info
            CONTINUE MENU
          END IF
          CLOSE FORM f
          EXIT MENU
        COMMAND "Exit"
          EXIT PROGRAM 0
      END MENU
    ELSE
      LABEL redisplay:
      LET mt1 = os.Path.mtime(fname)
      LET size1 = os.Path.size(fname)
      OPEN FORM f FROM fname
      DISPLAY FORM f
      MENU
        ON IDLE 1
          IF NOT os.Path.exists(fname) OR isInvalid(fname) THEN
            CLOSE FORM f
            EXIT MENU
          END IF
          IF changedTimeAndSize(fname, mt1, size1) THEN
            CLOSE FORM f
            GOTO redisplay
          END IF
        ON ACTION refresh ATTRIBUTE(IMAGE = "refresh")
          CLOSE FORM f
          GOTO redisplay
        COMMAND "Exit"
          EXIT PROGRAM 0
      END MENU
    END IF
  END WHILE
END MAIN

FUNCTION isInvalid(fname)
  DEFINE fname STRING
  DEFINE testdoc om.DomDocument
  LET testdoc = om.DomDocument.createFromXmlFile(fname)
  RETURN testdoc IS NULL
END FUNCTION

FUNCTION myonclose()
  DISPLAY "!!!!!!!!myonclose"
END FUNCTION

FUNCTION changedTimeAndSize(fname, mt1, size1)
  DEFINE fname STRING
  DEFINE mt1, mt2 DATETIME YEAR TO SECOND
  DEFINE size1, size2 INT
  LET mt2 = os.Path.mtime(fname)
  LET size2 = os.Path.size(fname)
  IF mt2 <> mt1 OR size1 <> size2 THEN
    RETURN TRUE
  END IF
  RETURN FALSE
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
