#+ small generator program to create fglcm_c.css and fglcm_c.js from
#+ the original codemirror assets
#+ this is to avoid too many FT round trips (originally over 20 vs 2 )
#+ and speeds up the initial start in slow networks
MAIN
  DEFINE ch base.Channel
  LET ch=base.Channel.create()
  CALL ch.openFile("fglcm_c.css","w")
  CALL ch.writeLine("/* this file is generated by coalesce.4gl , do not edit, all changes will be lost in the next generation */")
  CALL cpFromSrc("codemirror/lib/codemirror.css",ch)
  CALL cpFromSrc("codemirror/addon/display/fullscreen.css",ch)
  CALL cpFromSrc("codemirror/theme/eclipse.css",ch)
  CALL cpFromSrc("codemirror/addon/hint/show-hint.css",ch)
  CALL cpFromSrc("codemirror/addon/dialog/dialog.css",ch)
  CALL cpFromSrc("codemirror/addon/search/matchesonscrollbar.css",ch)
  CALL cpFromSrc("codemirror/addon/lint/lint.css",ch)
  CALL cpFromSrc("fglcm.css",ch)
  CALL ch.close()
  CALL ch.openFile("fglcm_c.js","w")
  CALL ch.writeLine("/* this file is generated by coalesce.4gl , do not edit, all changes will be lost in the next generation */")
  CALL cpFromSrc("codemirror/addon/display/fullscreen.js",ch)
  CALL cpFromSrc("codemirror/mode/xml/xml.js",ch)
  CALL cpFromSrc("codemirror/mode/javascript/javascript.js",ch)
  CALL cpFromSrc("codemirror/addon/hint/show-hint.js",ch)
  CALL cpFromSrc("codemirror/addon/hint/javascript-hint.js",ch)
  CALL cpFromSrc("codemirror/addon/dialog/dialog.js",ch)
  CALL cpFromSrc("codemirror/addon/search/searchcursor.js",ch)
  CALL cpFromSrc("codemirror/addon/search/search.js",ch)
  CALL cpFromSrc("codemirror/addon/scroll/annotatescrollbar.js",ch)
  CALL cpFromSrc("codemirror/addon/search/matchesonscrollbar.js",ch)
  CALL cpFromSrc("codemirror/addon/search/jump-to-line.js",ch)
  CALL cpFromSrc("codemirror/addon/edit/matchbrackets.js",ch)
  CALL cpFromSrc("codemirror/keymap/vim.js",ch)
  CALL cpFromSrc("codemirror/addon/lint/lint.js",ch)
  CALL cpFromSrc("customMode/makefile.js",ch)
  --CALL cpFromSrc("experimental/linthelper.js")
  --CALL cpFromSrc("experimental/markers.js")
  CALL ch.close()
END MAIN

FUNCTION cpFromSrc(srcFile,destCh)
  DEFINE srcFile,line STRING
  DEFINE srcCh,destCh base.Channel
  LET srcCh=base.Channel.create()
  CALL srcCh.openFile(srcFile,"r")
  CALL destCh.writeLine(sfmt("/* begin %1 */",srcFile))
  WHILE (line:=srcCh.readLine()) IS NOT NULL
    CALL destCh.writeLine(line)
  END WHILE
  CALL destCh.writeLine(sfmt("/* end %1 */",srcFile))
  CALL srcCh.close()
END FUNCTION
