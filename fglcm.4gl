OPTIONS
SHORT CIRCUIT
IMPORT util
IMPORT os
IMPORT FGL fgldialog
--IMPORT FGL fglcm_core
IMPORT FGL fglped_md_filedlg
IMPORT FGL fglped_fileutils
IMPORT FGL fglwebrun
&define _ASSERT(x) IF NOT NVL(x,0) THEN CALL assert(#x) END IF
&define _ASSERT_MSG(x,msg) IF NOT NVL(x,0) THEN CALL assert_with_msg(#x,msg) END IF
&define UNUSED_VAR(x) IF (x) IS NULL THEN END IF
--the webcomponents value->used in the main INPUT
PUBLIC DEFINE m_cm STRING
--how many extension actions are there
PUBLIC CONSTANT numExtensionActions = 10
PUBLIC CONSTANT S_CANCEL = "*cancel*"

CONSTANT S_ERROR = "Error"
--error image
CONSTANT IMG_ERROR = "stop"

--CONSTANT TAG_TOOLBAR="ToolBar"
--CONSTANT TAG_TOOLBARITEM="ToolBarItem"

TYPE proparr_t DYNAMIC ARRAY OF STRING
TYPE TStringDict DICTIONARY OF STRING
--DEFINE m_om STRING
DEFINE m_omCount INT
DEFINE m_lastWindowId INT
DEFINE m_gbcInitSeen BOOLEAN
DEFINE m_error_line STRING
DEFINE m_cline, m_ccol INT
DEFINE m_srcfile STRING
DEFINE m_tmpname STRING
DEFINE m_title, m_full_title STRING
DEFINE compile_arr DYNAMIC ARRAY OF STRING
DEFINE m_CRCProg STRING
DEFINE m_lastCRC BIGINT
DEFINE m_lastSyncNum BIGINT
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
DEFINE m_formatSource BOOLEAN
DEFINE m_InitSeen BOOLEAN
DEFINE m_gbcdir STRING
DEFINE m_PreviewOrient STRING
DEFINE m_hiddenTB om.DomNode
--CONSTANT HIGHBIT32=2147483648 -- == 0x80000000
TYPE RecentsEntry RECORD
  fileName STRING,
  cursor1 RECORD
    line INT,
    ch INT
  END RECORD,
  cursor2 RECORD
    line INT,
    ch INT
  END RECORD
END RECORD

TYPE CmCursor RECORD
  cursor1 RECORD
    line INT,
    ch INT
  END RECORD,
  cursor2 RECORD
    line INT,
    ch INT
  END RECORD
END RECORD

TYPE ModelArray DYNAMIC ARRAY OF RECORD
  line STRING,
  orgnum INT
END RECORD

DEFINE m_mark CmCursor
DEFINE m_recents DYNAMIC ARRAY OF RecentsEntry
DEFINE m_lastEditorInstruction STRING

DEFINE m_savedlines DYNAMIC ARRAY OF STRING

DEFINE m_orglines ModelArray

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
  syncNum INT,
  cursor1 RECORD
    line INT,
    ch INT
  END RECORD,
  cursor2 RECORD
    line INT,
    ch INT
  END RECORD,
  proparr proparr_t,
  vm BOOLEAN, --we set this to true whenever 4GL wants to change values
  cmdIdx INT, --force reload
  extension STRING, --extension of or source file
  cmCommand STRING, --editor command to perform in CodeMirror
  feedAction
      STRING, --action to be tunneled thru and feed to ourselves in a round trip
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
    severity STRING,
    errfile STRING
  END RECORD,
  flushTimeout INT
END RECORD

DEFINE m_cmRec CmType
DEFINE m_arg_0 STRING
DEFINE m_args DYNAMIC ARRAY OF STRING
DEFINE m_qa_chooseFileName STRING
DEFINE m_qa_saveAsFileName STRING
DEFINE m_qa_file_new_ext STRING
DEFINE m_previewFF om.DomNode
DEFINE m_dummyFF om.DomNode

FUNCTION resetForQA() --reset all vars
  INITIALIZE m_cm TO NULL
  INITIALIZE m_error_line TO NULL
  LET m_cline = 0
  LET m_ccol = 0
  INITIALIZE m_srcfile TO NULL
  INITIALIZE m_tmpname TO NULL
  INITIALIZE m_title, m_full_title TO NULL
  CALL compile_arr.clear()
  INITIALIZE m_CRCProg TO NULL
  LET m_lastCRC = NULL
  LET m_modified = FALSE
  LET m_IsNewFile = FALSE
  LET m_mainFormOpen = FALSE
  LET m_previewHidden = FALSE
  INITIALIZE m_NewFileExt TO NULL
  LET m_cmdIdx = 0
  LET m_lastSyncNum = 0
  INITIALIZE m_lastCompiled4GL TO NULL
  INITIALIZE m_lastCompiledPER TO NULL
  INITIALIZE m_locationhref TO NULL
  INITIALIZE m_extURL TO NULL --external form viewer URL
  INITIALIZE _on_mac TO NULL --cache the file_on_mac
  LET m_IsFiddle = FALSE
  LET m_InitSeen = FALSE
  CALL m_recents.clear()
  INITIALIZE m_lastEditorInstruction TO NULL
  CALL m_savedlines.clear()
  CALL m_orglines.clear()
  INITIALIZE m_cmRec TO NULL
  INITIALIZE m_arg_0 TO NULL
  CALL m_args.clear()
  INITIALIZE m_qa_chooseFileName TO NULL
END FUNCTION

FUNCTION init_args()
  DEFINE i INT
  FOR i = 1 TO num_args()
    LET m_args[i] = arg_val(i)
  END FOR
  LET m_arg_0 = arg_val(0)
  CALL initGBCWebCo()
END FUNCTION

FUNCTION initGBCWebCo()
  DEFINE gbcdest, currver, gbcver, webco STRING
  --DISPLAY "initGBCWebCo()"
  LET gbcdest = selfpathjoin("webcomponents/gbc")
  CALL checkGBCAvailable()
  _ASSERT(m_gbcdir IS NOT NULL)
  LET gbcver = join(m_gbcdir, "VERSION")
  LET currver = join(gbcdest, "VERSION")
  LET webco = join(gbcdest, "gbc.html")
  IF NOT file_equal(gbcver, currver, FALSE) OR NOT os.Path.exists(webco) THEN
    --DISPLAY "webco file newly created"
    --CALL cpChecked(join(m_gbcdir,"index.html"),webco)
  END IF
  CALL cpGBCAssets2Dest(m_gbcdir, gbcdest)
  --install our custom bootstrap file
  --CALL cpChecked(selfpathjoin("gbc.bootstrap.js"),join(join(gbcdest,"js"),"gbc.bootstrap.js"))
END FUNCTION

FUNCTION setArgs(arg0, args)
  DEFINE arg0 STRING
  DEFINE args DYNAMIC ARRAY OF STRING
  LET m_arg_0 = arg0
  LET m_args = args
END FUNCTION

FUNCTION selfpathjoin(what)
  DEFINE what STRING
  RETURN myjoin(mydir(my_arg_val(0)), what)
END FUNCTION

FUNCTION my_arg_val(index)
  DEFINE index INT
  IF index == 0 THEN
    RETURN m_arg_0
  ELSE
    IF index >= 1 AND index <= m_args.getLength() THEN
      RETURN m_args[index]
    END IF
  END IF
  RETURN NULL
END FUNCTION

FUNCTION parseVersion(version)
  DEFINE version STRING
  DEFINE fversion, testversion FLOAT
  DEFINE pointpos, major, idx INTEGER
  --cut out major.minor from the version
  LET pointpos = version.getIndexOf(".", 1)
  _ASSERT(pointpos <> 0 AND pointpos <> 1)
  LET major = version.subString(1, pointpos - 1)
  _ASSERT(major IS NOT NULL AND major < 100)
  --go a long as possible thru the string after '.' and remember the last
  --valid conversion, so it doesn't matter if a '.' or something else is right hand side of major.minor
  LET idx = 1
  LET fversion = NULL
  WHILE (testversion := version.subString(1, pointpos + idx)) IS NOT NULL
      AND pointpos + idx <= version.getLength()
    LET fversion = testversion
    --DISPLAY "fversion:",fversion," out of:",version.subString(1,pointpos+idx)
    LET idx = idx + 1
  END WHILE
  _ASSERT(fversion IS NOT NULL AND fversion > 0.0)
  RETURN fversion
END FUNCTION

FUNCTION init()
  DEFINE cli, ver STRING
  DEFINE fver FLOAT
  LET cli = ui.Interface.getFrontEndName()
  LET ver = ui.Interface.getFrontEndVersion()
  LET fver = parseVersion(ver)
  CALL patch_webco("fglcm")
  --CALL patch_webco("gbc")
  CALL log(SFMT("cli:%1,fver:%2", cli, fver))
  IF cli == "GDC" AND fver < 3.1 THEN
    CALL err(
        SFMT("You need a GDC version>=3.10 to run fglcm, you have GDC version:%1",
            ver))
  END IF
  LET m_IsFiddle = fgl_getenv("FGLFIDDLE") IS NOT NULL
  --DISPLAY "m_IsFiddle:", m_IsFiddle
  CALL ui.Interface.loadStyles("fglcm")
  --CALL initCRC32Table()
  CALL loadKeywords()
  LET m_lastCRC = NULL
  LET m_CRCProg = os.Path.fullPath(selfpathjoin("crc32"))
  CALL log(SFMT("m_CRCProg:%1", m_CRCProg))
  IF NOT os.Path.exists(m_CRCProg) OR NOT os.Path.executable(m_CRCProg) THEN
    LET m_CRCProg = NULL
  END IF
END FUNCTION

FUNCTION before_input(d, activateAndHideActions)
  DEFINE d ui.Dialog
  DEFINE activateAndHideActions BOOLEAN
  DEFINE i INT
  --DISPLAY "before_input,activateAndHideActions:", activateAndHideActions
  IF activateAndHideActions AND d IS NOT NULL THEN
    CALL d.setActionActive("run", FALSE)
    CALL setPreviewActionActive(FALSE)
    CALL d.setActionActive("main4gl", m_IsFiddle)
    CALL d.setActionActive("mainper", m_IsFiddle)
    CALL d.setActionActive("browse_demos", m_IsFiddle)
    CALL d.setActionHidden("main4gl", NOT m_IsFiddle)
    CALL d.setActionHidden("mainper", NOT m_IsFiddle)
    CALL d.setActionHidden("browse_demos", NOT m_IsFiddle)
    FOR i = 1 TO numExtensionActions
      CALL d.setActionHidden(SFMT("fglcm_ext%1", i), TRUE)
    END FOR
  END IF
  IF d IS NULL THEN
    CALL checkPreviewOrientInit()
    RETURN
  END IF
  CALL initialize_when(TRUE)
  CALL compileTmp(m_PreviewOrient IS NULL)
  CALL display_full(FALSE, FALSE)
  IF m_PreviewOrient IS NOT NULL THEN
    LET m_PreviewOrient = NULL
    CALL gotoMark()
  END IF
  CALL flush_cm()
END FUNCTION

FUNCTION checkPreviewOrientInit()
  _ASSERT(m_PreviewOrient IS NOT NULL)
  CALL togglePreviewOrient2()
  LET m_cmdIdx = 0
  LET m_cm = NULL
  LET m_lastCRC = NULL
  LET m_lastSyncNum = 0
END FUNCTION

FUNCTION cleanup()
  CALL delete_tmpfiles()
  DISPLAY NULL TO webpreview
  CALL os.Path.delete(getSession42f()) RETURNING status
END FUNCTION

FUNCTION deleteLog()
  DEFINE logfile STRING
  LET logfile = fgl_getenv("FGLCM_LOGFILE")
  IF logfile IS NOT NULL THEN
    CALL log(SFMT("remove log at :%1", logfile))
    CALL os.Path.delete(logfile) RETURNING status
  END IF
END FUNCTION

FUNCTION doClose(exit)
  DEFINE exit BOOLEAN
  IF checkFileSave() = S_CANCEL THEN
    RETURN
  END IF
  CALL cleanup()
  IF NOT exit THEN
    CLOSE WINDOW fglcm
  END IF
  CALL deleteLog()
  IF exit THEN
    CALL myExit("doClose", 0)
  END IF
END FUNCTION

FUNCTION getFormToolBar()
  DEFINE nlist om.NodeList
  DEFINE fNode om.DomNode
  LET fNode = getCurrentFormNode()
  LET nlist = fNode.selectByTagName("ToolBar")
  RETURN IIF(nlist.getLength() > 0, nlist.item(1), NULL)
END FUNCTION

FUNCTION removeFromParent(n)
  DEFINE n, p om.DomNode
  LET p = n.getParent()
  IF p IS NOT NULL THEN
    CALL p.removeChild(n)
  END IF
END FUNCTION

FUNCTION checkFiddleBar()
  DEFINE tb om.DomNode
  IF m_IsFiddle THEN
    RETURN
  END IF
  --remove the bar when not in fiddle mode
  LET tb = getFormToolBar()
  IF tb IS NOT NULL THEN
    CALL removeFromParent(tb)
  END IF
END FUNCTION

FUNCTION mydir(path)
  DEFINE path STRING
  DEFINE dirname STRING
  LET dirname = os.Path.dirName(path)
  IF dirname IS NULL THEN
    LET dirname = "."
  END IF
  RETURN dirname
END FUNCTION

FUNCTION myjoin(path1, path2)
  DEFINE path1, path2 STRING
  RETURN os.Path.join(path1, path2)
END FUNCTION

FUNCTION isGBC()
  RETURN ui.Interface.getFrontEndName() == "GBC"
END FUNCTION

FUNCTION getCurrentForm()
  DEFINE w ui.Window
  LET w = ui.Window.getCurrent()
  RETURN w.getForm()
END FUNCTION

FUNCTION getCurrentFormNode()
  DEFINE frm ui.Form
  LET frm = getCurrentForm()
  _ASSERT(frm IS NOT NULL)
  RETURN frm.getNode()
END FUNCTION

FUNCTION setPreviewActionActive(active)
  DEFINE active BOOLEAN
  DEFINE item om.DomNode
  DEFINE f ui.Form
  CALL setActionActive("preview", active)
  CALL setActionActive("showpreviewurl", active)
  IF NOT m_IsFiddle THEN
    RETURN
  END IF
  LET item = getToolBarItemByName("preview")
  IF item IS NOT NULL THEN
    LET f = getCurrentForm()
    CALL f.setElementHidden("preview", NOT active)
  END IF
END FUNCTION

FUNCTION hideOrShowPreview()
  DEFINE isPER, wasHidden BOOLEAN
  --IF NOT isGBC() THEN
  --  RETURN
  --END IF
  LET isPER =
      (m_IsNewFile AND ((m_NewFileExt IS NOT NULL) AND (m_NewFileExt == "per")))
          OR isPERFile(m_srcfile)
  CALL log(
      SFMT("hideOrShow m_srcfile:%1,isPERFile:%2,isPER:%3,hidden:%4",
          m_srcfile, isPERFile(m_srcfile), isPER, NOT isPER))
  LET wasHidden = m_previewHidden
  LET m_previewHidden = NOT isPER
  CALL hidePreviewTBActions(m_previewHidden)
  CALL hidePreview(m_previewHidden)
END FUNCTION

FUNCTION hidePreviewTBActions(hide)
  DEFINE hide BOOLEAN
  DEFINE tb, ch om.DomNode
  DEFINE numhidden, num INT
  DEFINE name STRING
  LET tb = getFormToolBar()
  IF tb IS NULL AND (tb := m_hiddenTB) IS NULL THEN
    RETURN
  END IF
  _ASSERT(tb IS NOT NULL)
  LET ch = tb.getFirstChild()
  WHILE ch IS NOT NULL
    IF ch.getTagName() == "ToolBarItem" THEN
      LET num = num + 1
      LET name = ch.getAttribute("name")
      _ASSERT(name IS NOT NULL)
      IF name MATCHES "*preview*" THEN
        CALL ch.setAttribute("hidden", hide)
        LET numhidden = IIF(hide, numhidden + 1, numhidden)
      ELSE
        LET numhidden =
            IIF(ch.getAttribute("hidden") == "1", numhidden + 1, numhidden)
      END IF
    END IF
    LET ch = ch.getNext()
  END WHILE
  --hide the toolbar if all items are hidden
  CALL hideToolBar(tb, hide AND numhidden == num)
END FUNCTION

FUNCTION hideToolBar(tb, hide)
  DEFINE tb, fNode om.DomNode
  DEFINE hide BOOLEAN
  _ASSERT(tb IS NOT NULL)
  CALL log(SFMT("hideToolBar:%1", hide))
  IF hide THEN
    LET m_hiddenTB = tb
    CALL removeFromParent(tb)
  ELSE
    IF m_hiddenTB IS NOT NULL THEN
      _ASSERT(m_hiddenTB.getParent() IS NULL)
      LET fNode = getCurrentFormNode()
      CALL fNode.appendChild(m_hiddenTB)
      LET m_hiddenTB = NULL
    END IF
  END IF
END FUNCTION

FUNCTION nodeFromPathInt(p, path, checked)
  DEFINE p, n om.DomNode
  DEFINE path STRING
  DEFINE checked BOOLEAN
  DEFINE nl om.NodeList
  _ASSERT(p IS NOT NULL)
  LET nl = p.selectByPath(path)
  IF NOT checked AND nl.getLength() < 1 THEN
    RETURN NULL
  END IF
  _ASSERT(nl.getLength() == 1)
  LET n = nl.item(1)
  _ASSERT(n IS NOT NULL)
  RETURN n
END FUNCTION

FUNCTION nodeFromPath(p, path)
  DEFINE p om.DomNode
  DEFINE path STRING
  RETURN nodeFromPathInt(p, path, FALSE)
END FUNCTION

FUNCTION nodeFromPathChecked(p, path)
  DEFINE p om.DomNode
  DEFINE path STRING
  RETURN nodeFromPathInt(p, path, TRUE)
END FUNCTION

FUNCTION getToolBarItemByName(name)
  DEFINE name STRING
  DEFINE tb om.DomNode
  RETURN IIF((tb := getFormToolBar()) IS NOT NULL,
      nodeFromPath(tb, SFMT('//ToolBarItem[@name="%1"]', name)),
      NULL)
END FUNCTION

FUNCTION mvFromBoxToBoxInt(box1, box2, ff)
  DEFINE box1, box2, ff, p om.DomNode
  LET p = ff.getParent()
  _ASSERT(p.getTagName() == "Grid")
  CALL box1.removeChild(p)
  CALL box2.appendChild(p)
  CALL ff.setAttribute("hidden", "0")
  CALL p.setAttribute("hidden", "0")
END FUNCTION

FUNCTION resetGBCWebCo()
  LET m_omCount = 0
  LET m_gbcInitSeen = FALSE
  LET m_lastWindowId = 0
  DISPLAY NULL TO webpreview
END FUNCTION

FUNCTION mvFromBoxToBox(box1, box2, ff1, ff2)
  DEFINE box1, box2, ff1, ff2 om.DomNode
  CALL mvFromBoxToBoxInt(box1, box2, ff1)
  CALL mvFromBoxToBoxInt(box1, box2, ff2)
  CALL box1.setAttribute("hidden", "1")
  CALL box2.setAttribute("hidden", "0")
END FUNCTION

FUNCTION displayState()
  IF fgl_getenv("VERBOSE") IS NOT NULL THEN
  DISPLAY "m_lastCRC:", m_lastCRC
  DISPLAY "m_lastCompiled4GL:", m_lastCompiled4GL
  DISPLAY "m_lastCompiledPER:", m_lastCompiledPER
  DISPLAY "m_orglines:", util.JSON.stringify(m_orglines)
  DISPLAY "m_savedlines:", util.JSON.stringify(m_savedlines)
  DISPLAY "m_cmRec:", util.JSON.stringify(m_cmRec)
  DISPLAY "m_cm:", m_cm
  END IF
END FUNCTION

FUNCTION togglePreviewOrient1()
  DEFINE fNode, ff1, p om.DomNode
  CALL markCursor()
  LET fNode = getCurrentFormNode()
  LET ff1 = nodeFromPathChecked(fNode, '//FormField[@name="formonly.cm"]')
  LET p = ff1.getParent()
  _ASSERT(p.getTagName() == "Grid")
  LET p = p.getParent()
  LET m_PreviewOrient = p.getTagName()
  --DISPLAY "togglePreviewOrient1 m_PreviewOrient:", m_PreviewOrient
  --CALL displayState()
END FUNCTION

FUNCTION nodeForPreview()
  RETURN nodeFromPathChecked(
      getCurrentFormNode(), '//FormField[@name="formonly.webpreview"]')
END FUNCTION

FUNCTION togglePreviewOrient2()
  DEFINE fNode, ff1, ff2, p, p2, vbox, hbox om.DomNode
  DEFINE ptag STRING
  _ASSERT(m_PreviewOrient IS NOT NULL)
  LET fNode = getCurrentFormNode()
  LET ff1 = nodeFromPathChecked(fNode, '//FormField[@name="formonly.cm"]')
  LET ff2 = nodeForPreview()
  LET p = ff1.getParent()
  _ASSERT(p.getTagName() == "Grid")
  LET p = p.getParent()
  LET ptag = p.getTagName()
  CALL log(SFMT("m_PreviewOrient:%1,ptag:%2", m_PreviewOrient, ptag))
  IF ptag == "HBox" AND m_PreviewOrient == "VBox"
      OR ptag == "VBox" AND m_PreviewOrient == "HBox" THEN
    CALL ff2.setAttribute("hidden", "0")
    LET p2 = ff2.getParent()
    _ASSERT(p2.getTagName() == "Grid")
    CALL p2.setAttribute("hidden", "0")
    --DISPLAY "orient already ok"
  ELSE
    IF ptag == "HBox" AND m_PreviewOrient == "HBox" THEN
      LET vbox = nodeFromPathChecked(fNode, '//VBox[@name="fglcm_vbox"]')
      CALL mvFromBoxToBox(p, vbox, ff1, ff2)
    ELSE
      _ASSERT(m_PreviewOrient == "VBox")
      LET hbox = nodeFromPathChecked(fNode, '//HBox[@name="fglcm_hbox"]')
      CALL mvFromBoxToBox(p, hbox, ff1, ff2)
    END IF
  END IF
  CALL resetGBCWebCo()
  CALL hidePreview(FALSE)
END FUNCTION

FUNCTION togglePreviewVisibility()
  DEFINE fNode, grid om.DomNode
  DEFINE gridhidden, isNowHidden BOOLEAN
  LET fNode = getCurrentFormNode()
  LET grid = nodeFromPathChecked(fNode, '//Grid[@name="fglcm_grid_webpreview"]')
  LET gridhidden = grid.getAttribute("hidden") == "1"
  LET isNowHidden = NOT gridhidden
  CALL hidePreview(isNowHidden)
END FUNCTION

FUNCTION hidePreview(hide)
  DEFINE hide, vert BOOLEAN
  DEFINE f ui.Form
  DEFINE tbi, tbo, ff2, p om.DomNode
  LET f = getCurrentForm()
  CALL f.setElementHidden("fglcm_grid_webpreview", hide)
  CALL f.setFieldHidden("formonly.webpreview", hide)
  IF (tbi := getToolBarItemByName("toggle_preview_visibility")) IS NOT NULL THEN
    LET ff2 = nodeForPreview()
    IF NOT hide AND ff2 == m_dummyFF THEN
      _ASSERT(m_previewFF IS NOT NULL)
      LET ff2 = m_previewFF
      CALL edit2webco()
      CALL f.setFieldHidden("formonly.webpreview", hide)
    END IF
    _ASSERT((p := ff2.getParent()) IS NOT NULL)
    _ASSERT((p := p.getParent()) IS NOT NULL)
    LET vert = p.getTagName() == "VBox"
    LET tbo = getToolBarItemByName("toggle_preview_orient")
    _ASSERT(tbo IS NOT NULL)
    IF hide THEN
      CALL tbi.setAttribute("text", "Show Split Preview")
      CALL tbi.setAttribute(
          "image", IIF(vert, "fa-toggle-up", "fa-toggle-left"))
      CALL tbo.setAttribute("hidden", "1")
    ELSE
      CALL tbi.setAttribute("text", "Hide Split Preview")
      CALL tbi.setAttribute(
          "image", IIF(vert, "fa-toggle-down", "fa-toggle-right"))
      CALL tbo.setAttribute("hidden", "0")
      CALL tbo.setAttribute(
          "image", IIF(vert, "preview_horizontal.svg", "preview_vertical.svg"))
      CALL tbo.setAttribute("text", IIF(vert, "Split Horiz.", "Split Vert."))
    END IF
  ELSE
    --DISPLAY "no toggle_preview_visibility item found:"
  END IF
  {
  IF NOT wasHidden AND m_previewHidden THEN
    CALL os.Path.delete(getSession42f()) RETURNING dummy
    --DISPLAY NULL TO webpreview
  END IF
  }
END FUNCTION

FUNCTION openMainWindow()
  DEFINE w ui.Window
  CALL fgl_refresh()
  LET w = ui.Window.forName("screen")
  IF w IS NOT NULL THEN
    --DISPLAY "close screen"
    CLOSE WINDOW screen
  END IF
  OPEN WINDOW fglcm AT 1, 1 WITH 10 ROWS, 10 COLUMNS
  CALL displayForm()
  CALL checkFiddleBar()
END FUNCTION

FUNCTION displayForm()
  IF m_mainFormOpen THEN
    CLOSE FORM fglcm
  END IF
  OPEN FORM fglcm FROM "fglcm"
  DISPLAY FORM fglcm
  LET m_mainFormOpen = TRUE
  LET m_previewFF = NULL
  LET m_dummyFF = NULL
  CALL webco2edit()
END FUNCTION

PRIVATE FUNCTION open_prepare()
  DEFINE ans STRING
  IF (ans := checkFileSave()) = S_CANCEL THEN
    RETURN S_CANCEL
  END IF
  CALL initialize_when(TRUE)
  IF ans = "no" THEN
    CALL display_full(FALSE, FALSE)
    CALL savelines()
  END IF
  RETURN NULL
END FUNCTION

PRIVATE FUNCTION open_load(cname)
  DEFINE cname STRING
  IF NOT file_read(cname) THEN
    CALL restorelines()
    CALL fgl_winMessage(S_ERROR, SFMT("Can't read:%1", cname), IMG_ERROR)
    LET cname = NULL
  ELSE
    CALL resetNewFile()
    LET m_lastCRC = NULL
    CALL savelines()
    CALL setCurrFile(cname)
    CALL display_full(FALSE, FALSE)
  END IF
  IF NOT isPERFile(m_tmpname) THEN
    CALL setPreviewActionActive(FALSE)
  END IF
  CALL hideOrShowPreview()
  RETURN cname
END FUNCTION

PRIVATE FUNCTION open_finish(cname)
  DEFINE cname STRING
  CALL open_finish_int(cname, FALSE)
END FUNCTION

PRIVATE FUNCTION open_finish_int(cname, dontjump_to_error)
  DEFINE cname STRING
  DEFINE dontjump_to_error BOOLEAN
  --note we compile unconditinally because the buffers may have changed
  CALL compileTmp((cname IS NOT NULL) AND dontjump_to_error == FALSE)
  CALL flush_cm()
END FUNCTION

FUNCTION doFileOpen(cname)
  DEFINE cname, res STRING
  LET res = open_prepare()
  IF res IS NOT NULL THEN
    RETURN
  END IF
  IF cname IS NULL THEN
    LET cname = fglped_filedlg()
  END IF
  IF cname IS NOT NULL THEN
    LET cname = open_load(cname)
  END IF
  CALL open_finish(cname)
END FUNCTION

FUNCTION doFileSave()
  IF m_srcfile IS NULL THEN
    CALL doFileSaveAs()
    RETURN
  END IF
  IF NOT file_write(m_srcfile, FALSE) THEN
    CALL fgl_winMessage(S_ERROR, SFMT("Can't write:%1", m_srcfile), IMG_ERROR)
    --TODO: handle this worst case
  ELSE
    IF m_IsNewFile THEN
      CALL resetNewFile()
      CALL mysetTitle()
    END IF
    CALL log(SFMT("saved to:%1", m_srcfile))
    CALL savelines()
    CALL initialize_when(TRUE)
    CALL compileTmp(FALSE)
    CALL flush_cm()
    CALL mymessage(SFMT("saved:%1", m_srcfile))
  END IF
END FUNCTION

FUNCTION doFileSaveAs()
  DEFINE saveasfile STRING
  IF (saveasfile := fglped_saveasdlg(m_srcfile)) IS NOT NULL THEN
    IF NOT file_write(saveasfile, FALSE) THEN
      CALL fgl_winMessage(
          S_ERROR, SFMT("Can't write:%1", saveasfile), IMG_ERROR)
    ELSE
      CALL setCurrFile(saveasfile)
      CALL savelines()
      CALL resetNewFile()
      CALL mysetTitle()
      CALL display_full(TRUE, TRUE)
    END IF
  END IF
END FUNCTION

FUNCTION doFileNew()
  DEFINE ans STRING
  IF (ans := checkFileSave()) = S_CANCEL THEN
    CALL log("doFileNew checkFileSave S_CANCEL")
    RETURN
  END IF
  CALL initialize_when(TRUE)
  IF file_new(NULL) == S_CANCEL THEN
    CALL log("doFileNew file_new S_CANCEL")
    RETURN
  END IF
  CALL display_full(FALSE, FALSE)
  CALL setCurrFile("")
  CALL compileTmp(FALSE)
  CALL hideOrShowPreview()
  CALL flush_cm()
END FUNCTION

FUNCTION doComplete()
  DEFINE dummy STRING
  IF NOT my_write(m_tmpname, TRUE) THEN
    CALL myExit("doComplete", 1)
  END IF
  CALL initialize_when(TRUE)
  LET m_cmRec.proparr = complete()
  CALL compile_and_process(FALSE) RETURNING dummy
  CALL flush_cm()
END FUNCTION

FUNCTION doCompile(jump_to_error)
  DEFINE jump_to_error BOOLEAN
  CALL initialize_when(TRUE)
  CALL compileTmp(jump_to_error)
  CALL flush_cm()
END FUNCTION

FUNCTION formatSource()
  LET m_formatSource = TRUE
  CALL initialize_when(TRUE)
  CALL compileTmp(TRUE)
  LET m_formatSource = FALSE
  IF m_cmRec.annotations.getLength() == 0 THEN
    --formatting successful
    CALL display_full(FALSE, FALSE)
    CALL jump_to_line(m_cline, m_ccol, m_cline, m_ccol, FALSE, FALSE)
  END IF
  CALL flush_cm()
END FUNCTION

FUNCTION doFind()
  CALL initialize_when(TRUE)
  LET m_cmRec.cmCommand = "find"
  CALL compileTmp(FALSE)
  CALL flush_cm()
END FUNCTION

FUNCTION doReplace()
  CALL initialize_when(TRUE)
  LET m_cmRec.cmCommand = "replace"
  CALL compileTmp(FALSE)
  CALL flush_cm()
END FUNCTION

FUNCTION markCursor()
  LET m_mark.cursor1.* = m_cmRec.cursor1.*
  LET m_mark.cursor2.* = m_cmRec.cursor2.*
END FUNCTION

FUNCTION gotoMark()
  --CALL initialize_when(initialize)
  LET m_cmRec.cursor1.* = m_mark.cursor1.*
  LET m_cmRec.cursor2.* = m_mark.cursor2.*
  --CALL flush_when(flush)
END FUNCTION

FUNCTION normalizeName(pwd, name)
  DEFINE pwd, name, parent, pre STRING
  IF name IS NULL THEN
    RETURN "(NULL)"
  END IF
  IF name.getIndexOf(pwd, 1) == 1 THEN
    --print short names for current dir and sub dirs
    RETURN name.subString(pwd.getLength() + 2, name.getLength())
  END IF
  LET parent = pwd
  LET pre = ".."
  WHILE (parent := os.Path.dirName(parent)) IS NOT NULL
    IF name.getIndexOf(parent, 1) == 1 THEN
      RETURN os.Path.join(
          pre, name.subString(parent.getLength() + 2, name.getLength()))
    END IF
    LET pre = pre, "/.."
  END WHILE
  RETURN name
END FUNCTION

PRIVATE FUNCTION displayPickList()
  DEFINE entry, el, pwd, full STRING
  DEFINE i INT
  DEFINE arr DYNAMIC ARRAY OF STRING
  LET full = os.Path.fullPath(m_srcfile)
  LET pwd = os.Path.pwd()
  FOR i = 1 TO m_recents.getLength()
    _ASSERT(m_recents[i].fileName IS NOT NULL)
    IF NOT full.equals(m_recents[i].fileName) THEN
      LET el = m_recents[i].fileName
      LET el = normalizeName(pwd, el)
      --IF pwd.equals(os.Path.dirName(el)) THEN
      --  LET el=os.Path.baseName(el)
      --END IF
      LET arr[arr.getLength() + 1] = el
    END IF
  END FOR
  CALL log(
      SFMT("m_recents:%1,arr:%2",
          util.JSON.stringify(m_recents), util.JSON.stringify(arr)))
  IF arr.getLength() == 0 THEN
    CALL fgl_winMessage(
        "fglcm", "There are no alternate files you did edit previously", "info")
    RETURN NULL
  END IF
  OPEN WINDOW fglcm_picklist
      WITH
      FORM "fglcm_picklist"
      ATTRIBUTE(STYLE = "dialog")
  MESSAGE "Pick one of the files you did edit previously and hit <Return>"
  DISPLAY ARRAY arr TO pick.*
    ON ACTION accept
      LET entry = arr[arr_curr()]
      EXIT DISPLAY
  END DISPLAY
  CLOSE WINDOW fglcm_picklist
  RETURN entry
END FUNCTION

FUNCTION openFromPickList()
  DEFINE cname, res STRING
  DEFINE re RecentsEntry
  LET res = open_prepare()
  IF res IS NOT NULL THEN
    RETURN
  END IF
  LET cname = displayPickList()
  IF cname IS NOT NULL THEN
    LET cname = open_load(cname)
  END IF
  IF cname IS NOT NULL THEN
    _ASSERT(m_recents.getLength() >= 1)
    LET re.* = m_recents[1].*
    LET m_cmRec.cursor1.* = re.cursor1.*
    LET m_cmRec.cursor2.* = re.cursor2.*
    CALL open_finish_int(cname, re.cursor1.line IS NOT NULL)
  ELSE
    CALL open_finish(cname)
  END IF
END FUNCTION

FUNCTION browse_demos()
  DEFINE cname, res STRING
  LET res = open_prepare()
  IF res IS NOT NULL THEN
    RETURN
  END IF
  LET cname = run_demos()
  IF cname IS NOT NULL THEN
    LET cname = open_load(cname)
    LET m_cmRec.cmCommand = "reload"
  END IF
  CALL open_finish(cname)
END FUNCTION

FUNCTION run_demos()
  DEFINE cmd, dir, fulldir, cmdemo, home, tmp, line, lastline, cname STRING
  DEFINE code INT
  DEFINE ch base.Channel
  LET dir = os.Path.dirName(my_arg_val(0))
  LET fulldir = os.Path.fullPath(dir)
  LET cmdemo = myjoin(fulldir, "cmdemo.42m")
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
  LET home = fgl_getenv("FGLDIR")
  IF home IS NULL THEN
    MESSAGE "Can't find FGLDIR"
    RETURN NULL
  END IF
  LET home = os.Path.join(home, "demo")
  IF NOT os.Path.exists(home) AND NOT os.Path.isDirectory(home) THEN
    MESSAGE SFMT("Can't find fiddle home:%1", home)
    RETURN NULL
  END IF
  IF NOT os.Path.fullPath(os.Path.pwd()) == os.Path.fullPath(home) THEN
    LET cmd = "cd ", home, "&&"
  END IF
  LET tmp = os.Path.makeTempName()
  LET cmd = cmd, "fglrun ", cmdemo, " >", tmp, " 2>&1"
  CALL log(SFMT("Run demo:%1", cmd))
  RUN cmd RETURNING code
  IF code == 0 THEN
    LET ch = base.Channel.create()
    TRY
      CALL ch.openFile(tmp, "r")
      WHILE (line := ch.readLine()) IS NOT NULL
        --DISPLAY "line:", line
        LET lastline = line
      END WHILE
      CALL ch.close()
      IF lastline.getIndexOf("COPY2FIDDLE:", 1) <> 1 THEN
        CALL myERROR("Can't find COPY2FIDDLE")
      ELSE
        LET cname = lastline.subString(13, lastline.getLength())
        --DISPLAY "!!!cname:", cname
      END IF
    CATCH
      CALL myERROR(SFMT("read failed:%1", err_get(status)))
    END TRY
  ELSE
    CALL myERROR(SFMT("Returned with code:%1", code))
    RUN "cat " || tmp
  END IF
  CALL os.Path.delete(tmp) RETURNING code
  RETURN cname
END FUNCTION

PRIVATE FUNCTION compileTmp(jump_to_error)
  DEFINE compmess STRING
  DEFINE jump_to_error BOOLEAN
  IF is4GLOrPerFile(m_tmpname) THEN
    LET compmess = saveAndCompile(jump_to_error)
    IF compmess IS NULL THEN
      CALL mymessage(IIF(m_formatSource, "Formatting ok", "Compile ok"))
      IF isPERFile(m_tmpname) THEN
        CALL livePreview(m_tmpname)
      END IF
    END IF
  END IF
END FUNCTION

FUNCTION getLiveURL(prog, arg)
  DEFINE prog, arg STRING
  DEFINE dirname, base STRING
  DEFINE questpos INT
  LET base =
      fgl_getenv(
          "FGL_VMPROXY_START_URL") --https://fglfiddle.com:443/gas/ua/r/cm
  --DISPLAY "base:",base,",m_locationhref:",m_locationhref
  IF base IS NOT NULL THEN
    --https://fglfiddle.com:443/gas/ua/r/_fglcm_preview
    RETURN myjoin(os.Path.dirName(base), SFMT("%1?Arg=%2", prog, arg))

  END IF
  --http://localhost:6395/gwc-js/index.html?app=_cm
  LET base = fgl_getenv("FGL_WEBSERVER_HTTP_REFERER")
  IF base IS NOT NULL THEN
    LET questpos = base.getIndexOf("?", 1)
    IF questpos > 0 THEN
      LET base = base.subString(1, questpos - 1)
      RETURN SFMT("%1?app=%2&Arg=%3", base, prog, arg)
    END IF
  END IF
  IF m_locationhref IS NOT NULL THEN
    LET base = m_locationhref
    WHILE (dirname := os.Path.dirName(base)) IS NOT NULL
        AND dirname <> "."
        AND os.Path.baseName(dirname) <> "ua"
      LET base = dirname
      --DISPLAY "base:",base
    END WHILE
    RETURN myjoin(myjoin(dirname, "r"), SFMT("%1&Arg=%2", prog, arg))
  END IF
  RETURN "."
END FUNCTION

FUNCTION checkAppDataXCF()
  DEFINE gaspub, gasappdatadir STRING
  LET gaspub = fgl_getenv("GAS_PUBLIC_DIR")
  IF gaspub IS NULL THEN
    RETURN
  END IF
  LET gasappdatadir = mydir(gaspub)
  LET gasappdatadir = myjoin(gasappdatadir, "app")
  --DISPLAY "gaspub:", gaspub, ",gasappdatadir:", gasappdatadir
  CALL writeXCF(gasappdatadir, "fglcm_webpreview")
  CALL writeXCF(gasappdatadir, "spex")
END FUNCTION

FUNCTION writeXCF(gasappdatadir, appname)
  DEFINE gasappdatadir, appname STRING
  DEFINE xcfname, xcfcontent STRING
  DEFINE args DYNAMIC ARRAY OF STRING
  DEFINE c base.Channel
  LET xcfname = myjoin(gasappdatadir, appname || ".xcf")
  IF os.Path.exists(xcfname) THEN
    RETURN
  END IF
  CALL fglwebrun.setupVariables()
  CALL fglwebrun.createXCF(xcfname, "fglcm_webpreview", args, FALSE)
  RETURN
  LET xcfcontent =
      SFMT('<?xml version="1.0"?>\n'
              || '<APPLICATION Parent="defaultgwc" '
              || '    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
              || '    xsi:noNamespaceSchemaLocation="http://www.4js.com/ns/gas/2.30/cfextwa.xsd">\n'
              || '  <EXECUTION AllowUrlParameters="TRUE">\n'
              || '    <PATH>%1</PATH>\n'
              || '    <MODULE>%2</MODULE>\n'
              || '  </EXECUTION>\n'
              || '</APPLICATION>',
          mydir(my_arg_val(0)), appname)
  LET c = base.Channel.create()
  TRY
    CALL c.openFile(xcfname, "w")
  CATCH
    DISPLAY "Can't open xcf:", xcfname
    RETURN
  END TRY
  CALL c.writeLine(xcfcontent)
  CALL c.close()
  --DISPLAY "Did write XCF:", xcfname, ",with Content:", xcfcontent
END FUNCTION

FUNCTION livePreview(tmpname)
  DEFINE tmpname STRING
  DEFINE liveurl STRING
  UNUSED_VAR(tmpname)
  UNUSED_VAR(liveurl)
  IF NOT m_gbcInitSeen THEN
    CALL log("livePreview:no init")
    RETURN
  END IF
  CALL initGBC()

  --CALL copyTmp2Session42f(tmpname)
  --CALL checkAppDataXCF()
  --LET liveurl=getLiveURL("fglcm_webpreview",util.Strings.urlEncode(getSessionId()))
  #LET liveurl=myjoin(base,util.Strings.urlEncode(sfmt("_fglcm_webpreview?Arg=%1",dirname)))
  #LET liveurl=myjoin(base,sfmt("_fglcm_webpreview?Arg=%1",util.Strings.urlEncode(real42f)))
  --DISPLAY "liveurl:",liveurl
  --DISPLAY liveurl TO webpreview
  LET m_extURL = getLiveURL("spex", util.Strings.urlEncode(getSessionId()))
END FUNCTION

FUNCTION runprog()
  DEFINE srcname, cmdir, cmd, info, tmp42m, dummy, line STRING
  DEFINE c base.Channel
  DEFINE code INT

  CALL compileAllForms(
      IIF(m_IsFiddle, os.Path.pwd(), os.Path.dirName(m_tmpname)))
  IF (m_lastCompiledPER == m_tmpname) THEN
    --need to cp the current tmp 42f fo the real 42f
    CALL copyTmp2Real42f(m_tmpname) RETURNING dummy
  END IF
  IF m_IsFiddle THEN
    LET srcname = ".@main.4gl"
  ELSE
    LET srcname = m_lastCompiled4GL
  END IF
  LET tmp42m = srcname.subString(1, srcname.getLength() - 4)
  LET cmdir = mydir(my_arg_val(0))
  IF m_IsFiddle THEN
    LET cmd =
        myjoin(cmdir, "startfglrun.sh"),
        " ",
        os.Path.pwd(),
        " ",
        tmp42m,
        ".42m >result.out 2>&1"
  ELSE
    LET cmd = SFMT("fglrun %1 >result.out 2>&1", tmp42m)
  END IF
  RUN cmd RETURNING code
  LET info = SFMT("Returned code from %1: %2\n", tmp42m, code)
  LET c = base.Channel.create()
  TRY
    CALL c.openFile("result.out", "r")
    WHILE (line := c.readLine()) IS NOT NULL
      IF line == "fglrun sandbox enabled" THEN
        CONTINUE WHILE
      END IF
      LET code = -1
      LET info = info, line, "\n"
    END WHILE
    CALL c.close()
  CATCH
    LET code = 256
    LET info = info, SFMT("Failed to read result.txt:%1", err_get(status))
  END TRY
  IF code <> 0 THEN
    OPEN WINDOW output WITH FORM "fglcm_output"
    DISPLAY info TO info
    MENU
      ON ACTION cancel ATTRIBUTE(TEXT = "Close")
        EXIT MENU
    END MENU
    CLOSE WINDOW output
  ELSE
    CALL mymessage("Program ended with success and no output")
  END IF
END FUNCTION

FUNCTION to42f(pername)
  DEFINE pername STRING
  RETURN pername.subString(1, pername.getLength() - 4) || ".42f"
END FUNCTION

FUNCTION compileAllForms(dirpath)
  DEFINE dirpath STRING
  DEFINE dh, code INTEGER
  DEFINE fname, name42f, cmd STRING
  DEFINE mtper, mt42f DATETIME YEAR TO SECOND
  LET dh = os.Path.dirOpen(dirpath)
  IF dh == 0 THEN
    DISPLAY "Can't open directory:", dirpath
    RETURN
  END IF
  WHILE TRUE
    LET fname = os.Path.dirNext(dh)
    IF fname IS NULL THEN
      EXIT WHILE
    END IF
    IF NOT isPERFile(fname) THEN
      CONTINUE WHILE
    END IF
    LET fname = os.Path.join(dirpath, fname)
    IF os.Path.isDirectory(fname) THEN
      CONTINUE WHILE
    END IF
    LET name42f = to42f(fname)
    IF os.Path.exists(name42f) THEN
      LET mtper = os.Path.mtime(fname)
      LET mt42f = os.Path.mtime(name42f)
      CALL log(SFMT("%1 mtper:%2,mt42f:%3", fname, mtper, mt42f))
      IF mt42f >= mtper THEN
        CALL log(SFMT("%1 already compiled", fname))
        CONTINUE WHILE
      END IF
    END IF
    LET cmd = buildCompileCmd(dirpath, "fglform", "", fname)
    LET cmd = cmd, "&1"
    RUN cmd RETURNING code
    IF code THEN
      DISPLAY "Can't compile:", fname
    ELSE
      DISPLAY "Compiled:", fname
    END IF
  END WHILE
  CALL os.Path.dirClose(dh)
END FUNCTION

FUNCTION copyTmp2Real42f(tmpname)
  DEFINE tmpname STRING
  DEFINE tmp42f, tmp42fLast, real42f STRING
  DEFINE code INT
  LET tmp42f = to42f(tmpname)
  LET tmp42fLast = os.Path.baseName(tmp42f)
  LET real42f =
      myjoin(
          os.Path.dirName(tmp42f),
          tmp42fLast.subString(3, tmp42fLast.getLength()))
  CALL log(SFMT("tmp42f:%1,real42f:%2", tmp42f, real42f))
  CALL os.Path.copy(tmp42f, real42f) RETURNING code
  RETURN real42f
END FUNCTION

FUNCTION getSessionId()
  DEFINE sessId STRING
  LET sessId = fgl_getenv("FGL_VMPROXY_SESSION_ID")
  LET sessId = sessId.subString(1, 6)
  RETURN sessId
END FUNCTION

FUNCTION getSession42f()
  DEFINE sessionId STRING
  LET sessionId = getSessionId()
  IF sessionId IS NULL THEN
    DISPLAY "No session id"
    RETURN NULL
  END IF
  RETURN SFMT("/tmp/fglcm_%1.42f", sessionId)
END FUNCTION

FUNCTION removeWebComponentType(root)
  DEFINE root, node om.DomNode
  DEFINE nl om.NodeList
  DEFINE i INT
  DEFINE txt STRING
  LET nl = root.selectByPath("//WebComponent")
  FOR i = 1 TO nl.getLength()
    LET node = nl.item(i)
    CALL node.removeAttribute("componentType")
  END FOR
  LET txt = root.getAttribute("text")
  IF txt IS NULL THEN
    CALL root.setAttribute("text", "<No text>")
  END IF
END FUNCTION

--we delete webcomponents componentType attribute if we
--encounter webcomponents otherwise the whole GBC dies
PRIVATE FUNCTION copyDocWithoutComponentType(src, dest)
  DEFINE src, dest STRING
  DEFINE doc om.DomDocument
  DEFINE rootNode om.DomNode
  LET doc = om.DomDocument.createFromXmlFile(src)
  IF doc IS NULL THEN
    RETURN
  END IF
  LET rootNode = doc.getDocumentElement()
  CALL removeWebComponentType(rootNode)
  CALL rootNode.writeXml(dest)
END FUNCTION

FUNCTION copyTmp2Session42f(tmpname)
  DEFINE tmpname STRING
  DEFINE tmp42f, session42f STRING
  LET tmp42f = tmpname.subString(1, tmpname.getLength() - 4), ".42f"
  LET session42f = getSession42f()
  IF session42f IS NOT NULL THEN
    --CALL os.Path.copy(tmp42f,session42f) RETURNING code
    CALL copyDocWithoutComponentType(tmp42f, session42f)
  END IF
END FUNCTION

FUNCTION preview_form()
  DEFINE tmp42f STRING
  LET tmp42f = m_lastCompiledPER
  LET tmp42f = tmp42f.subString(1, tmp42f.getLength() - 4), ".42f"
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
  OPEN WINDOW sc AT 0, 0 WITH 25 ROWS, 60 COLUMNS ATTRIBUTES(STYLE = "preview")
  OPEN FORM theform FROM ff
  DISPLAY FORM theform
  MENU "Preview"
    ON ACTION myclose ATTRIBUTE(TEXT = "Close (Escape)", ACCELERATOR = "Escape")
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
  MESSAGE msg -- in GDC Mac this message sometimes causes black flicker
  }
END FUNCTION

FUNCTION setInitSeen()
  LET m_InitSeen = TRUE
  CALL log("setInitSeen")
  DISPLAY m_cm TO cm
END FUNCTION

FUNCTION fcsync() --called if our topmenu fired an action
  --we do not use the new 3.10 onFlush Webco mechanism because we want to use
  --the 3.00 GDC too, so we have to explicitly flush the component
  --the drawback: this costs an additional client server round trip
  DEFINE newVal STRING
  IF NOT m_InitSeen THEN
    CALL log("fcsync:no init seen yet")
    RETURN
  END IF
  --DISPLAY "!!!!fcsync called!!!!"
  CALL ui.Interface.frontCall(
      "webcomponent", "call", ["formonly.cm", "fcsync"], [newVal])
  --DISPLAY "newVal:", newVal

  CALL syncInt(newVal)
END FUNCTION

FUNCTION sync() --called if the webco fired an action
  DEFINE cmRec CmType
  DEFINE buf STRING
  LET buf = fgl_dialog_getbuffer()
  CALL util.JSON.parse(buf, cmRec)
  CALL log(
      SFMT("sync(): cmRec.syncNum:%1,m_lastSyncNum:%2,cmRec.vm:%3",
          cmRec.syncNum, m_lastSyncNum, cmRec.vm))
  IF cmRec.vm == TRUE
      OR cmRec.syncNum IS NULL
      OR cmRec.syncNum <= m_lastSyncNum THEN
    CALL fcsync()
  ELSE
    CALL syncInt(buf)
  END IF
END FUNCTION

PRIVATE FUNCTION syncInt(newVal)
  DEFINE newVal, line STRING
  DEFINE orgnum, idx, i, j, z, len, insertpos INT
  DEFINE cmRec CmType
  CALL log(SFMT("syncInt newVal:%1", newVal))
  _ASSERT(newVal IS NOT NULL)
  LET m_lastEditorInstruction = newVal
  CALL util.JSON.parse(newVal, cmRec)
  --DISPLAY "cm:",util.JSON.stringify(cmRec)
  --DISPLAY ">>----"
  --LET src=cmRec.full
  LET m_cline = cmRec.cursor1.line + 1
  LET m_ccol = cmRec.cursor1.ch + 1
  _ASSERT_MSG(cmRec.syncNum = m_lastSyncNum + 1, sfmt("cmRec.syncNum:%1,m_lastSyncNum:%2", cmRec.syncNum, m_lastSyncNum))
  LET m_lastSyncNum = cmRec.syncNum
  CALL updateRecentsCursor(cmRec.cursor1.*, cmRec.cursor2.*)
  LET m_locationhref = cmRec.locationhref
  LET len = cmRec.modified.getLength()
  FOR i = 1 TO len
    LET orgnum = cmRec.modified[i].orgnum + 1
    IF orgnum >= 1 AND orgnum <= m_orglines.getLength() THEN
      LET line = cmRec.modified[i].line
      IF checkChanged(line, m_orglines[orgnum].line) THEN
        CALL log(
            SFMT("patch line:%1 from:'%2' to:'%3'",
                orgnum, m_orglines[orgnum].line, line))
        CALL setModified()
        LET m_orglines[orgnum].line = line
      END IF
    ELSE
      DISPLAY SFMT("index out of range:%1 m_orglines.getLength():%2",
          orgnum, m_orglines.getLength())
    END IF
  END FOR
  IF cmRec.removed.getLength() > 0 THEN
    CALL setModified()
  END IF
  FOR i = cmRec.removed.getLength() TO 1 STEP -1
    LET m_modified = TRUE
    LET idx = cmRec.removed[i].idx + 1
    LET len = cmRec.removed[i].len
    CALL log(SFMT("delete lines:%1-%2", idx, idx + len - 1))
    FOR j = 1 TO len
      CALL log(SFMT("delete line:'%1'", m_orglines[idx].line))
      CALL m_orglines.deleteElement(idx)
    END FOR
  END FOR
  IF cmRec.inserts.getLength() > 0 THEN
    CALL setModified()
  END IF
  LET j = 1
  FOR i = 1 TO cmRec.inserts.getLength()
    LET m_modified = TRUE
    LET orgnum = cmRec.inserts[i].orgnum + 1
    WHILE j <= m_orglines.getLength()
      IF m_orglines[j].orgnum == orgnum THEN
        LET len = cmRec.inserts[i].ilines.getLength()
        CALL log(SFMT("insert %1 new lines at:%2", len, j + 1))
        FOR z = 1 TO len
          LET insertpos = j + z
          CALL m_orglines.insertElement(insertpos)
          LET m_orglines[insertpos].line = cmRec.inserts[i].ilines[z].line
          LET m_orglines[insertpos].orgnum = -1
        END FOR
        EXIT WHILE
      END IF
      LET j = j + 1
    END WHILE
  END FOR
  LET m_lastCRC = cmRec.crc
  CALL log(
      SFMT("syncNum:%1,len:%2, lineCount:%3,crc:%4",
          cmRec.syncNum, cmRec.len, cmRec.lineCount, m_cmRec.crc))
  IF m_orglines.getLength() <> cmRec.lineCount THEN
    CALL err(
        SFMT("linecount local %1 != linecount remote %2",
            m_orglines.getLength(), cmRec.lineCount))
  END IF
  --renumber and compute character count
  LET len = 0
  FOR i = m_orglines.getLength() TO 1 STEP -1
    LET line = m_orglines[i].line
    LET len = len + line.getLength()
    IF i <> 0 THEN
      LET len = len + 1 --newline
    END IF
    LET m_orglines[i].orgnum = i
  END FOR
  IF len <> m_cmRec.len THEN
    CALL err(
        SFMT("character count local %1 != character count remote %2",
            len, cmRec.len))
  END IF
  --CALL displayState()
END FUNCTION

PRIVATE FUNCTION flush_cm()
  DEFINE flushTimeout INT
  LET m_cmdIdx = m_cmdIdx + 1
  LET m_cmRec.cmdIdx = m_cmdIdx
  LET m_cmRec.vm = TRUE
  LET flushTimeout = fgl_getenv("FGLCM_FLUSHTIMEOUT")
  LET m_cmRec.flushTimeout =
      IIF((flushTimeout IS NULL) OR flushTimeout == "0", 1000, flushTimeout)
  LET m_cm = util.JSON.stringifyOmitNulls(m_cmRec)
  {
  IF m_cm.getLength() > 140 THEN
    DISPLAY SFMT("flush:%1...%2",
        m_cm.subString(1, 70),
        m_cm.subString(m_cm.getLength() - 60, m_cm.getLength()))
  ELSE
    DISPLAY "flush:", m_cm
  END IF
  }
  --CALL fgl_dialog_setbuffer(m_cm)
  DISPLAY m_cm TO cm
END FUNCTION
#+
FUNCTION feedAction(actionName)
  DEFINE actionName STRING
  CALL initialize_when(TRUE)
  LET m_cmRec.feedAction = actionName
  CALL flush_cm()
END FUNCTION

FUNCTION actionPending()
  IF m_cmRec.feedAction IS NOT NULL THEN
    CALL log(SFMT("actionPending:%1", m_cmRec.feedAction))
    RETURN TRUE
  END IF
  RETURN FALSE
END FUNCTION

FUNCTION doGotoLine()
  DEFINE lineno INT
  LET lineno = 1
  OPEN WINDOW gotoline WITH FORM "fglcm_gotoline"
  LET int_flag = FALSE
  INPUT BY NAME lineno WITHOUT DEFAULTS
  CLOSE WINDOW gotoline
  IF NOT int_flag THEN
    CALL jump_to_line(LINENO, 1, LINENO, 1, TRUE, TRUE)
  END IF
END FUNCTION

PRIVATE FUNCTION initialize_when(initialize)
  DEFINE initialize BOOLEAN
  IF initialize THEN
    CALL log("initialize m_cmRec")
    INITIALIZE m_cmRec.* TO NULL
  END IF
END FUNCTION

PRIVATE FUNCTION flush_when(flush)
  DEFINE flush BOOLEAN
  IF flush THEN
    CALL flush_cm()
  END IF
END FUNCTION

--line and character numbers in codemirror start with 0
PRIVATE FUNCTION line2cm(line)
  DEFINE line INT
  RETURN line - 1
END FUNCTION

PRIVATE FUNCTION jump_to_line(linenum, col, line2, col2, initialize, flush)
  DEFINE linenum, col, line2, col2 INT
  DEFINE initialize, flush BOOLEAN
  CALL initialize_when(initialize)
  LET m_cmRec.cursor1.line = line2cm(linenum)
  LET m_cmRec.cursor1.ch = line2cm(col)
  LET m_cmRec.cursor2.line = line2cm(line2)
  LET m_cmRec.cursor2.ch =
      IIF(linenum == line2 AND col == col2, line2cm(col), col2)
  CALL flush_when(flush)
END FUNCTION

PRIVATE FUNCTION display_full(initialize, flush)
  DEFINE initialize, flush BOOLEAN
  DEFINE ext, basename STRING
  CALL initialize_when(initialize)
  LET m_cmRec.full = arr2String()
  IF m_IsNewFile AND m_srcfile IS NULL THEN
    LET m_cmRec.fileName = SFMT("newfile%1.%2", m_cmdIdx, m_NewFileExt)
    LET m_cmRec.extension = m_NewFileExt
  ELSE
    LET ext = os.Path.extension(m_srcfile)
    LET basename = os.Path.baseName(m_srcfile)
    LET m_cmRec.fileName = m_srcfile
    CASE
      WHEN ext.getLength() > 0
        LET m_cmRec.extension = ext
      WHEN basename.toLowerCase() == "makefile"
        LET m_cmRec.extension = "makefile"
    END CASE
  END IF
  CALL log(
      SFMT("display_full:%1,ext:%2,basename:%3",
          m_srcfile, m_cmRec.extension, basename))
  CALL flush_when(flush)
  LET m_lastCRC = NULL
  CALL displayState()
END FUNCTION

FUNCTION setActionActive(name, active)
  DEFINE name STRING
  DEFINE active BOOLEAN
  DEFINE d ui.Dialog
  LET d = ui.Dialog.getCurrent()
  CALL d.setActionActive(name, active)
END FUNCTION

PRIVATE FUNCTION compile_and_process(jump_to_error)
  DEFINE jump_to_error BOOLEAN
  DEFINE compmess STRING
  LET compmess = compile_source(m_tmpname, 0)
  IF compmess IS NOT NULL THEN
    CALL process_compile_errors(m_tmpname, jump_to_error)
  END IF
  RETURN compmess
END FUNCTION

PRIVATE FUNCTION saveAndCompile(jump_to_error)
  DEFINE jump_to_error BOOLEAN
  DEFINE compmess STRING
  IF file_write(m_tmpname, TRUE) THEN
    LET compmess = compile_and_process(jump_to_error)
  ELSE
    LET m_error_line = SFMT("Can't write to:%1", m_tmpname)
    CALL fgl_winMessage(S_ERROR, m_error_line, IMG_ERROR)
  END IF
  RETURN compmess
END FUNCTION

PRIVATE FUNCTION buildCompileCmd(dirname, compOrForm, cparam, fname)
  DEFINE dirname, compOrForm, cparam, fname STRING
  DEFINE cmd, baseName STRING
  CALL log(SFMT("buildCompileCmd dirname:%1", dirname))
  LET baseName = os.Path.baseName(fname)
  --we cd into the directory of the source
  IF file_on_windows() THEN
    LET cmd =
        SFMT("cd \"%1\" && %2 %3 -M -Wall %4 2>",
            dirname, compOrForm, cparam, baseName)
  ELSE
    LET cmd =
        SFMT("cd \"%1\" && %2 %3 -M -Wall \"%4\" 2>",
            dirname, compOrForm, cparam, baseName)
  END IF
  RETURN cmd
END FUNCTION

FUNCTION regularFromTmpName(tmpname)
  DEFINE tmpname, srcname STRING
  DEFINE atidx INT
  IF tmpname == m_tmpname AND m_srcfile IS NOT NULL THEN
    RETURN m_srcfile
  END IF
  IF (atidx := tmpname.getIndexOf(".@", 1)) > 0 THEN
    LET srcname =
        tmpname.subString(1, atidx - 1),
        tmpname.subString(atidx + 2, tmpname.getLength())
    RETURN srcname
  END IF
  RETURN tmpname
END FUNCTION

PRIVATE FUNCTION compile_source(fname, proposals)
  DEFINE fname STRING
  DEFINE proposals INT
  DEFINE dirname, cmd, cmd1, mess, cparam, line, srcname, compOrForm, tmpName
      STRING
  DEFINE result, tmpName2 STRING
  DEFINE code, i, dummy INT
  DEFINE isPER BOOLEAN
  LET dirname = mydir(fname)
  LET isPER = isPERFile(fname)
  IF isPER THEN
    LET cparam = "-c"
  END IF
  IF proposals THEN
    LET cparam = "-L"
  END IF
  CASE
    WHEN isPER OR proposals
      LET cparam = SFMT("%1 %2,%3", cparam, m_cline, m_ccol)
    WHEN NOT isPER AND m_IsFiddle
      LET cparam = "-r"
    WHEN NOT isPER AND m_formatSource
      LET cparam = "--format"
  END CASE
  LET compOrForm = IIF(isPER, "fglform", "fglcomp")
  LET cmd = buildCompileCmd(dirname, compOrForm, cparam, fname)
  CALL compile_arr.clear()
  CALL log(SFMT("compile_source cmd=%1", cmd))
  IF proposals THEN
    --DISPLAY "cmd=",cmd
  END IF
  IF NOT proposals THEN
    LET tmpName = os.Path.makeTempName()
    LET cmd1 = cmd, tmpName
    IF m_formatSource THEN
      LET tmpName2 = os.Path.makeTempName()
      LET cmd1 = cmd1, " >", tmpName2
    END IF
    RUN cmd1 RETURNING code
    IF isPER THEN
      CALL setPreviewActionActive(code == 0)
      LET m_lastCompiledPER = IIF(code == 0, fname, NULL)
    ELSE
      CALL setActionActive("run", code == 0)
      LET m_lastCompiled4GL = IIF(code == 0, fname, NULL)
    END IF
    IF NOT code AND os.Path.size(tmpName) > 0 THEN
      LET code = 400 --warnings occured
    END IF
  END IF
  IF code OR proposals THEN
    IF proposals THEN
      LET cmd = cmd, "&1"
      CALL fglped_fileutils.file_get_output(cmd, compile_arr)
    ELSE
      CALL file_read_in_arr(tmpName, compile_arr)
      --RUN "cat "||tmpName
    END IF
    LET srcname = regularFromTmpName(fname)
    --DISPLAY "srcname=",srcname
    LET mess = "compiling of '", srcname, "' failed:\n"
    FOR i = 1 TO compile_arr.getLength()
      LET line = compile_arr[i]
      IF line.getIndexOf(".@", 1) > 0 THEN
        LET compile_arr[i] = regularFromTmpName(line)
      END IF
      LET mess = mess, compile_arr[i], "\n"
    END FOR
    LET result = mess
  ELSE
    IF m_formatSource THEN
      IF NOT file_read(tmpName2) THEN
        CALL err("Can't read formatted source")
      END IF
    END IF
  END IF
  IF tmpName IS NOT NULL THEN
    CALL log(SFMT("delete tmpName:%1", tmpName))
    CALL os.Path.delete(tmpName) RETURNING dummy
  END IF
  IF tmpName2 IS NOT NULL THEN
    CALL log(SFMT("delete tmpName2:%1", tmpName))
    CALL os.Path.delete(tmpName2) RETURNING dummy
  END IF
  RETURN result
END FUNCTION

--calls the form compiler in completion mode
--and makes some computations to present a display array with possible
--completion tokens
PRIVATE FUNCTION complete()
  DEFINE compmess STRING
  DEFINE proposal STRING
  DEFINE proparr proparr_t
  DEFINE tok base.StringTokenizer
  DEFINE i, j, len INT
  DEFINE sub STRING
  LET compmess = compile_source(m_tmpname, 1)
  FOR i = 1 TO compile_arr.getLength()
    LET proposal = compile_arr[i]
    IF proposal.getIndexOf("proposal", 1) = 1 THEN
      CALL proparr.appendElement()
      LET len = proparr.getLength()
      LET tok = base.StringTokenizer.create(proposal, "\t")
      LET j = 1
      WHILE tok.hasMoreTokens()
        LET sub = tok.nextToken()
        CASE j
          WHEN 2
            LET proparr[len] = sub
            LET proposal = sub
          WHEN 3
            --LET proparr[len].kind=sub
        END CASE
        LET j = j + 1
      END WHILE
      --eliminite duplicates
      LET len = len - 1
      FOR j = 1 TO len
        IF proparr[j] = proposal THEN
          --DISPLAY "!!remove duplicate:",proposal
          CALL proparr.deleteElement(len + 1)
          EXIT FOR
        END IF
      END FOR
    END IF
  END FOR
  RETURN proparr
END FUNCTION

FUNCTION appendToLog(title, s)
  DEFINE title, s, logfile STRING
  DEFINE ch base.Channel
  LET logfile = fgl_getenv("FGLCM_LOGFILE")
  IF logfile IS NULL THEN
    RETURN
  END IF
  CALL log(SFMT("FGLCM_LOGFILE is:%1", logfile))
  LET ch = base.Channel.create()
  TRY
    CALL ch.openFile(logfile, "a")
    CALL ch.writeLine(title)
    CALL ch.writeLine(s)
    CALL ch.close()
  CATCH
    DISPLAY "ERROR appending log:", err_get(status)
  END TRY
END FUNCTION

FUNCTION err(errstr)
  DEFINE errstr STRING
  CALL fgl_winMessage("Error", errstr, "error")
  DISPLAY "ERROR:", errstr
  CALL appendToLog("fglcm.err():", errstr)
  EXIT PROGRAM 1
END FUNCTION

FUNCTION myERROR(errstr)
  DEFINE errstr STRING
  ERROR errstr
  DISPLAY "ERROR:", errstr
END FUNCTION

PRIVATE FUNCTION setModified()
  IF NOT m_modified THEN
    CALL log("setModified() TRUE")
    LET m_modified = TRUE
  END IF
END FUNCTION

PRIVATE FUNCTION checkChangedArray()
  DEFINE savelen, len, i INT
  IF m_modified == FALSE THEN
    CALL log("checkChangedArray() no mod")
    RETURN FALSE
  END IF
  LET savelen = m_savedlines.getLength()
  LET len = m_orglines.getLength()
  IF savelen <> len THEN
    --DISPLAY SFMT("savelen:%1 len:%2",savelen,len)
    RETURN TRUE
  END IF
  FOR i = 1 TO len
    IF checkChanged(m_savedlines[i], m_orglines[i].line) THEN
      DISPLAY SFMT("line:%1 differs '%2'<>'%3'",
          i, m_savedlines[i], m_orglines[i].line)
      RETURN TRUE
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

--the usual 4GL function  to check if 2 strings are different
FUNCTION checkChanged(src, copy2)
  DEFINE src STRING
  DEFINE copy2 STRING
  IF (copy2 IS NOT NULL AND src IS NULL)
      OR (copy2 IS NULL AND src IS NOT NULL)
      OR (copy2 <> src)
      OR (copy2.getLength() <> src.getLength()) THEN
    RETURN 1
  END IF
  RETURN 0
END FUNCTION

PRIVATE FUNCTION my_write(fname, internal)
  DEFINE fname STRING
  DEFINE internal BOOLEAN
  IF NOT file_write(fname, internal) THEN
    CALL fgl_winMessage(S_ERROR, SFMT("Can't write to:%1", fname), IMG_ERROR)
    RETURN FALSE
  END IF
  CALL log(SFMT("did write to:%1", fname))
  RETURN TRUE
END FUNCTION

--collects the errors and jumps to the first one optionally
PRIVATE FUNCTION process_compile_errors(fname, jump_to_error)
  DEFINE fname STRING
  DEFINE jump_to_error INT
  DEFINE idx, erridx INT
  DEFINE first BOOLEAN
  DEFINE firstcolon,
          secondcolon,
          thirdcolon,
          fourthcolon,
          fifthcolon,
          linenum,
          start
      INT
  DEFINE line, col, col2, linenumstr, line2numstr, errfile, regular STRING
  DEFINE isError BOOLEAN
  LET idx = 1
  LET m_error_line = ""
  IF idx > compile_arr.getLength() OR idx < 1 THEN
    RETURN
  END IF
  WHILE idx <= compile_arr.getLength() AND idx > 0
    LET line = compile_arr[idx]
    LET start = 1
    IF (firstcolon := line.getIndexOf(":", 1)) > 0
        AND firstcolon = 2
        AND line.getCharAt(3) = "\\" THEN
      --exclude drive letters under windows
      LET start = 3
    END IF
    IF (firstcolon := line.getIndexOf(":", start)) > 0
        AND ((isError := (line.getIndexOf(":error:", 1) <> 0) == TRUE)
            OR line.getIndexOf(":warning:", 1) <> 0) THEN
      LET errfile = line.subString(1, firstcolon - 1)
      IF fname IS NOT NULL THEN
        LET regular = regularFromTmpName(fname)
        IF os.Path.baseName(errfile) <> os.Path.baseName(regular) THEN
          DISPLAY "errfile:", errfile, ",regular:", regular
          DISPLAY "do not report warnings in other files yet to fglcm.js"
          LET idx = idx + 1
          CONTINUE WHILE
        END IF
      END IF
      LET secondcolon = line.getIndexOf(":", firstcolon + 1)
      LET thirdcolon = line.getIndexOf(":", secondcolon + 1)
      LET fourthcolon = line.getIndexOf(":", thirdcolon + 1)
      LET fifthcolon = line.getIndexOf(":", fourthcolon + 1)
      IF secondcolon > firstcolon THEN
        LET linenumstr = line.subString(firstcolon + 1, secondcolon - 1)
        LET col = line.subString(secondcolon + 1, thirdcolon - 1)
        LET line2numstr = line.subString(thirdcolon + 1, fourthcolon - 1)
        LET col2 = line.subString(fourthcolon + 1, fifthcolon - 1)
        LET linenum = linenumstr
        IF linenum > 0
            OR (linenumstr = "0" AND line.getIndexOf("expecting", 1) <> 0) THEN
          LET line = line.subString(firstcolon, line.getLength())
          LET m_error_line = line
          IF NOT first THEN
            LET first = TRUE
            CALL mymessage(m_error_line)
          END IF
          --ERROR m_error_line
          IF linenumstr = "0" THEN
            LET linenum = 1
          END IF
          LET erridx = m_cmRec.annotations.getLength() + 1
          LET m_cmRec.annotations[erridx].from.line = line2cm(linenum)
          LET m_cmRec.annotations[erridx].from.ch = line2cm(col)
          LET m_cmRec.annotations[erridx].to.line = line2cm(line2numstr)
          LET m_cmRec.annotations[erridx].to.ch = col2
          LET m_cmRec.annotations[erridx].message = m_error_line
          LET m_cmRec.annotations[erridx].severity =
              IIF(isError, "error", "warning")
          IF fname IS NULL THEN
            LET m_cmRec.annotations[erridx].errfile = errfile
          END IF
          IF jump_to_error THEN
            CALL jump_to_line(linenum, col, line2numstr, col2, FALSE, FALSE)
            LET jump_to_error = FALSE
          END IF
        END IF
      END IF
      --EXIT WHILE
    END IF
    LET idx = idx + 1
  END WHILE
END FUNCTION

FUNCTION copyModel(src, dest)
  DEFINE src, dest ModelArray
  DEFINE i, len INT
  CALL dest.clear()
  LET len = src.getLength()
  FOR i = 1 TO len
    LET dest[i].* = src[i].*
  END FOR
END FUNCTION

PRIVATE FUNCTION file_read(srcfile)
  DEFINE srcfile STRING
  DEFINE ch base.Channel
  DEFINE line STRING
  DEFINE linenum INT
  DEFINE backup ModelArray
  LET ch = base.Channel.create()
  CALL copyModel(m_orglines, backup)
  CALL m_orglines.clear()
  TRY
    CALL ch.openFile(srcfile, "r")
    LET linenum = 1
    IF status == 0 THEN
      WHILE NOT ch.isEof()
        LET line = ch.readLine()
        IF ch.isEof() THEN
          --we always have at least one line allocated
          IF line.getLength() == 0 AND linenum > 1 THEN
            EXIT WHILE
          END IF
        END IF
        LET m_orglines[linenum].line = line
        LET m_orglines[linenum].orgnum = linenum
        LET linenum = linenum + 1
      END WHILE
      CALL ch.close()
    END IF
    --DISPLAY "m_orglines:",util.JSON.stringify(m_orglines),",len:",m_orglines.getLength()
  CATCH
    DISPLAY err_get(status)
    CALL copyModel(backup, m_orglines)
    RETURN FALSE
  END TRY
  RETURN TRUE
END FUNCTION

PRIVATE FUNCTION file_read_in_arr(txtfile, arr)
  DEFINE txtfile STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE line STRING
  DEFINE ch base.Channel
  LET ch = base.Channel.create()
  CALL arr.clear()
  TRY
    CALL ch.openFile(txtfile, "r")
    IF status == 0 THEN
      WHILE NOT ch.isEof()
        LET line = ch.readLine()
        LET arr[arr.getLength() + 1] = line
      END WHILE
      CALL ch.close()
    END IF
    --DISPLAY "m_orglines:",util.JSON.stringify(m_orglines),",len:",m_orglines.getLength()
  CATCH
    DISPLAY err_get(status)
  END TRY
END FUNCTION

PRIVATE FUNCTION arr2String()
  DEFINE buf base.StringBuffer
  DEFINE result STRING
  DEFINE len, i INT
  LET buf = base.StringBuffer.create()
  LET len = m_orglines.getLength()
  FOR i = 1 TO len
    CALL buf.append(m_orglines[i].line)
    IF i <> len THEN
      CALL buf.append("\n")
    END IF
  END FOR
  LET result = buf.toString()
  IF result IS NULL THEN
    LET result = " " CLIPPED
  END IF
  RETURN result
END FUNCTION

PRIVATE FUNCTION file_write_int(srcfile, mode, internal)
  DEFINE srcfile STRING
  DEFINE mode STRING
  DEFINE internal BOOLEAN
  DEFINE ch base.Channel
  DEFINE result, mystatus INT
  DEFINE idx, len INT
  DEFINE line STRING
  LET ch = base.Channel.create()
  CALL ch.setDelimiter("")
  --DISPLAY "file_write_int:",os.Path.fullPath(srcfile)
  WHENEVER ERROR CONTINUE
  CALL ch.openFile(srcfile, mode)
  --CALL ch.setDelimiter("")
  LET mystatus = status
  WHENEVER ERROR STOP
  IF mystatus <> 0 THEN
    LET result = 0
  ELSE
    LET len = m_orglines.getLength()
    FOR idx = 1 TO len
      IF idx <> len OR NOT internal THEN
        --DISPLAY sfmt("writeLine %1 '%2'",idx,m_orglines[idx].line)
        CALL ch.writeLine(m_orglines[idx].line)
      ELSE
        --internal and last line: avoid the newline problem
        LET line = m_orglines[idx].line
        --DISPLAY sfmt("write last line %1 '%2'",idx,line)
        CALL ch.writeNoNL(line)
      END IF
    END FOR
    LET result = TRUE
    CALL ch.close()
  END IF
  RETURN result
END FUNCTION

PRIVATE FUNCTION file_write(srcfile, internal)
  DEFINE srcfile STRING
  DEFINE internal BOOLEAN
  DEFINE start DATETIME YEAR TO FRACTION(2)
  DEFINE result INT
  LET start = CURRENT
  LET result = file_write_int(srcfile, "w", internal)
  CALL log(
      SFMT("time for file_write:%1,m_lastCRC:%2", CURRENT - start, m_lastCRC))
  IF internal
      AND m_lastCRC IS NOT NULL
      AND (m_CRCProg IS NOT NULL OR file_on_mac()) THEN
    LET start = CURRENT
    CALL checkCRCSum(srcfile)
    CALL log(SFMT("time for cksum:%1,crc32:%2", CURRENT - start, m_cmRec.crc))
  END IF
  RETURN result
END FUNCTION

FUNCTION getCRCSum(fname)
  DEFINE fname, s, cmd STRING
  DEFINE tok base.StringTokenizer
  DEFINE first BIGINT
  IF m_CRCProg IS NOT NULL THEN
    LET cmd = SFMT("%1 %2", m_CRCProg, fname)
  ELSE --only mac
    LET cmd = SFMT("cksum -o 3 %1", fname)
  END IF
  LET s = file_get_output_string(cmd)
  CALL log(SFMT("%1 returned:%2", cmd, s))
  LET tok = base.StringTokenizer.create(s, " ")
  LET first = tok.nextToken()
  RETURN first
END FUNCTION

--should be only called in the accident case
--eats a full network roundtrip due to the frontcall
PRIVATE FUNCTION getFullTextAndRepair(fname)
  DEFINE fname STRING
  DEFINE r RECORD
    full STRING,
    crc32 BIGINT,
    lastChanges STRING,
    lineCount INT,
    log STRING
  END RECORD
  DEFINE ret, bak, last STRING
  DEFINE crc BIGINT
  LET m_lastCRC = NULL
  CALL ui.Interface.frontCall(
      "webcomponent", "call", ["formonly.cm", "getFullTextAndRepair"], [ret])
  CALL util.JSON.parse(ret, r)
  CALL writeStringToFile("lastWCLog.log", r.log)
  LET last = m_lastEditorInstruction, "\ncodemirror lastChanges:", r.lastChanges
  CALL writeStringToFile("lastChanges.txt", last)
  LET bak = SFMT("%1.bak", fname)
  RUN SFMT('cp "%1" "%2"', fname, bak)
  CALL writeStringToFile(fname, r.full)
  CALL appendToLog(
      "getFullTextAndRepair:",
      SFMT("Genero side in:%1, WC side in:%2", bak, fname))
  WHILE TRUE
    MENU ATTRIBUTE(STYLE = "dialog", COMMENT = "CRC error")
      COMMAND "vimdiff WC vs server"
        RUN SFMT('vimdiff "%1" "%2"', fname, bak)
      COMMAND "View WC side"
        RUN SFMT('fglrun "%1" "%2"', selfpathjoin("cm.42m"), fname)
      COMMAND "View server side"
        RUN SFMT('fglrun "%1" "%2"', selfpathjoin("cm.42m"), bak)
      COMMAND "View last changes"
        RUN SFMT('fglrun "%1" lastChanges.txt', selfpathjoin("cm.42m"))
      COMMAND "Continue Editing"
        EXIT WHILE
      COMMAND "Exit fglcm"
        CALL myExit("getFullTextAndRepair", 1)
    END MENU
  END WHILE
  LET crc = getCRCSum(fname)
  IF crc <> r.crc32 THEN
    DISPLAY "full:"
    DISPLAY "'", r.full, "\n'"
    DISPLAY "file:"
    RUN "cat '" || fname
    DISPLAY "'"
    CALL err(
        SFMT("getFullTextAndRepair crc cksum %1 != crc codemirror %2",
            crc, r.crc32))
  END IF
  CALL split_src(r.full)
  DISPLAY "lines:",
      m_orglines.getLength(),
      ",last:",
      m_orglines[m_orglines.getLength()].line,
      ",wc lineCount:",
      r.lineCount
  IF m_orglines.getLength() <> r.lineCount THEN
    CALL err(
        SFMT("getFullTextAndRepair m_orglines.getLength:%1, r.lineCount:%2",
            m_orglines.getLength(), r.lineCount))
  END IF
END FUNCTION

--writes a STRING 'as is' to a file
FUNCTION writeStringToFile(fname, s)
  DEFINE ch base.Channel
  DEFINE fname, s STRING
  LET ch = base.Channel.create()
  CALL ch.setDelimiter("")
  TRY
    CALL ch.openFile(fname, "w")
  CATCH
    CALL err(SFMT("writeStringToFile(%1) failed:%2", fname, err_get(status)))
  END TRY
  CALL ch.writeNoNL(s)
  CALL ch.close()
END FUNCTION

PRIVATE FUNCTION checkCRCSum(fname)
  DEFINE fname STRING
  DEFINE crc BIGINT
  LET crc = getCRCSum(fname)
  IF crc <> m_lastCRC THEN
    RUN "cat " || fname
    DISPLAY (SFMT("!!!!!!crc cksum %1 == crc codemirror %2", crc, m_lastCRC))
    --last resort:we fetch the whole editor content to repair the accident
    CALL getFullTextAndRepair(fname)
  END IF
  LET m_lastCRC = NULL
END FUNCTION

FUNCTION isWin()
  RETURN os.Path.separator() == "\\"
END FUNCTION

FUNCTION file_on_windows()
  RETURN os.Path.separator() == "\\"
END FUNCTION

FUNCTION _file_uname()
  DEFINE arr DYNAMIC ARRAY OF STRING
  IF file_on_windows() THEN
    RETURN "Windows"
  END IF
  CALL fglped_fileutils.file_get_output("uname", arr)
  IF arr.getLength() < 1 THEN
    RETURN "Unknown"
  END IF
  RETURN arr[1]
END FUNCTION

FUNCTION file_on_mac()
  IF _on_mac IS NULL THEN
    LET _on_mac = (_file_uname() == "Darwin")
  END IF
  RETURN _on_mac == "1"
END FUNCTION

#+cuts the extension from a file name
FUNCTION cut_extension(pname)
  DEFINE pname STRING
  DEFINE basename, ext STRING
  LET basename = pname
  LET ext = os.Path.extension(pname)
  IF ext IS NOT NULL THEN
    LET basename = pname.subString(1, pname.getLength() - (ext.getLength() + 1))
  END IF
  RETURN basename
END FUNCTION

FUNCTION checkFileSave()
  DEFINE ans STRING
  DEFINE dummy INT
  LET ans = "unchanged"
  IF checkChangedArray() THEN
    IF (ans
            := fgl_winQuestion(
                "fglcm",
                SFMT("Save changes to %1?", m_title),
                "yes",
                "yes|no|cancel",
                "question",
                0))
        = "yes" THEN
      IF m_srcfile IS NULL THEN
        LET m_srcfile = fglped_saveasdlg(m_srcfile)
        IF m_srcfile IS NULL THEN
          RETURN S_CANCEL
        END IF
      END IF
      CALL my_write(m_srcfile, FALSE) RETURNING dummy
      CALL savelines()
      IF m_IsNewFile THEN
        CALL resetNewFile()
        CALL mysetTitle()
      END IF
    END IF
  ELSE
    IF m_IsNewFile AND m_srcfile IS NOT NULL THEN
      CALL log(SFMT("delete '%1' because it was left virgin", m_srcfile))
      CALL os.Path.delete(m_srcfile) RETURNING status
    END IF
  END IF
  RETURN ans
END FUNCTION

FUNCTION log(msg)
  DEFINE msg STRING
  IF fgl_getenv("VERBOSE") IS NOT NULL THEN
    DISPLAY "LOG:", msg
  END IF
END FUNCTION

FUNCTION qaSetFileNewExt(ext)
  DEFINE ext STRING
  LET m_qa_file_new_ext = ext
END FUNCTION

PRIVATE FUNCTION file_new(ext)
  DEFINE ext STRING
  DEFINE cancel BOOLEAN
  DEFINE t TEXT
  IF m_qa_file_new_ext IS NOT NULL THEN
    LET ext = m_qa_file_new_ext
    LET m_qa_file_new_ext = NULL
  END IF
  IF ext IS NULL THEN
    OPEN WINDOW file_new
        WITH
        FORM "fglcm_filenew"
        ATTRIBUTE(TEXT = "Please choose a File type")
    MENU
      ON ACTION b4gl ATTRIBUTE(ACCELERATOR = "g")
        LET ext = "4gl"
        EXIT MENU
      ON ACTION bper ATTRIBUTE(ACCELERATOR = "f")
        LET ext = "per"
        EXIT MENU
      ON ACTION b4st ATTRIBUTE(ACCELERATOR = "s")
        LET ext = "4st"
        EXIT MENU
      ON ACTION cancel
        LET cancel = TRUE
        EXIT MENU
    END MENU
    CLOSE WINDOW file_new
    IF cancel THEN
      RETURN S_CANCEL
    END IF
  END IF
  CALL m_orglines.clear()
  LET m_orglines[1].line = " " CLIPPED
  LET m_orglines[1].orgnum = 1
  CASE ext
    WHEN "per"
      LET m_orglines[1].line = "LAYOUT"
      LET m_orglines[1].orgnum = 1
      LET m_orglines[2].line = "GRID"
      LET m_orglines[2].orgnum = 2
      LET m_orglines[3].line = "{"
      LET m_orglines[3].orgnum = 3
      LET m_orglines[4].line = "X"
      LET m_orglines[4].orgnum = 4
      LET m_orglines[5].line = "}"
      LET m_orglines[5].orgnum = 5
      LET m_orglines[6].line = "END"
      LET m_orglines[6].orgnum = 6
    WHEN "4st"
      LOCATE t
          IN FILE myjoin(myjoin(fgl_getenv("FGLDIR"), "lib"), "default.4st")
      CALL split_src(t)
  END CASE
  LET m_IsNewFile = TRUE
  LET m_NewFileExt = ext
  CALL savelines()
  CALL mymessage(SFMT("New file with extension:%1", ext))
  RETURN ext
END FUNCTION

FUNCTION getSrcFile()
  RETURN m_srcfile
END FUNCTION

FUNCTION canWrite(fname)
  DEFINE fname STRING
  DEFINE c base.Channel
  LET c = base.Channel.create()
  TRY
    CALL c.openFile(fname, "w")
  CATCH
    RETURN FALSE
  END TRY
  CALL c.close()
  CALL os.Path.delete(fname) RETURNING status
  RETURN TRUE
END FUNCTION

FUNCTION initSrcFile(fname)
  DEFINE fname STRING
  IF fname IS NULL THEN
    LET m_srcfile = NULL
    IF file_new(NULL) == S_CANCEL THEN
      RETURN FALSE
    END IF
  ELSE
    LET m_srcfile = fname
    IF NOT file_read(m_srcfile) THEN
      IF NOT os.Path.exists(m_srcfile) AND canWrite(m_srcfile) THEN
        IF file_new(os.Path.extension(m_srcfile)) == S_CANCEL THEN
          RETURN FALSE
        END IF
        IF NOT my_write(m_srcfile, FALSE) THEN
          RETURN FALSE
        END IF
      ELSE
        CALL fgl_winMessage(
            "fglcm",
            SFMT('The file "%1" does not exist and is also not usable for a new file (not writable)',
                fname),
            "error")
        RETURN FALSE
      END IF
    END IF
  END IF
  CALL setCurrFile(m_srcfile)
  CALL savelines()
  RETURN TRUE
END FUNCTION

PRIVATE FUNCTION setCurrFile(fname) --sets m_srcfile
  DEFINE fname STRING
  LET m_srcfile = fname
  CALL addToRecents()
  CALL delete_tmpfiles()
  LET m_tmpname = getTmpFileName(m_srcfile)
  CALL mysetTitle()
END FUNCTION

FUNCTION updateRecentsCursor(cursor1, cursor2)
  DEFINE cursor1 RECORD
    line INT,
    ch INT
  END RECORD
  DEFINE cursor2 RECORD
    line INT,
    ch INT
  END RECORD
  IF m_recents.getLength() == 0 OR m_srcfile IS NULL THEN
    RETURN
  END IF
  _ASSERT(m_recents[1].fileName == os.Path.fullPath(m_srcfile))
  LET m_recents[1].cursor1.* = cursor1.*
  LET m_recents[1].cursor2.* = cursor2.*
END FUNCTION

FUNCTION addToRecents()
  DEFINE i INT
  DEFINE found INT
  DEFINE foundEntry RecentsEntry
  DEFINE fullPath STRING
  INITIALIZE foundEntry.* TO NULL
  IF m_srcfile IS NULL THEN
    RETURN --ignore new files
  END IF
  LET fullPath = os.Path.fullPath(m_srcfile)
  FOR i = 1 TO m_recents.getLength()
    IF fullPath.equals(m_recents[i].fileName) THEN
      LET found = i
      LET foundEntry.* = m_recents[found].*
      EXIT FOR
    END IF
  END FOR
  IF found > 0 THEN
    CALL m_recents.deleteElement(found)
  END IF
  --insert in the head of recent list
  CALL m_recents.insertElement(1)
  LET foundEntry.fileName = fullPath
  LET m_recents[1].* = foundEntry.*
END FUNCTION

--computes the temporary .per file name to work with during our manipulations
FUNCTION getTmpFileName(fname)
  DEFINE fname STRING
  DEFINE tmpname STRING
  DEFINE dir, shortname STRING
  IF fname IS NULL THEN
    LET tmpname = ".@__empty__.", m_NewFileExt
  ELSE
    LET dir = mydir(fname)
    LET shortname = os.Path.baseName(fname)
    LET tmpname = myjoin(dir, SFMT(".@%1", shortname))
  END IF
  RETURN tmpname
END FUNCTION

--returns true if the current contents was initialized by File->New
--or File->New From Wizard
FUNCTION isNewFile()
  RETURN (m_srcfile IS NULL) OR m_IsNewFile
END FUNCTION

FUNCTION resetNewFile()
  LET m_IsNewFile = NULL
  LET m_NewFileExt = NULL
END FUNCTION

FUNCTION delete_tmpfiles()
  DEFINE dummy INT
  IF m_tmpname IS NULL THEN
    RETURN
  END IF
  CALL os.Path.delete(m_tmpname) RETURNING dummy
  CASE os.Path.extension(m_tmpname)
    WHEN "per"
      CALL os.Path.delete(cut_extension(m_tmpname) || ".42f") RETURNING dummy
    WHEN "4gl"
      CALL os.Path.delete(cut_extension(m_tmpname) || ".42m") RETURNING dummy
  END CASE
END FUNCTION

FUNCTION mysetTitle()
  DEFINE newfile STRING
  IF m_srcfile IS NULL THEN
    LET m_title = "Unnamed"
  ELSE
    LET m_title = os.Path.baseName(m_srcfile)
  END IF
  LET newfile = IIF(isNewFile(), " [New File]", "")
  LET m_full_title = SFMT("%1 - fglcm%2", m_title, newfile)
  CALL fgl_settitle(m_full_title)
END FUNCTION

FUNCTION mygetTitle()
  RETURN m_full_title
END FUNCTION

FUNCTION qaSetFileSaveAsFileName(fname)
  DEFINE fname STRING
  LET m_qa_saveAsFileName = fname
END FUNCTION

FUNCTION fglped_saveasdlg(fname)
  DEFINE fname STRING
  DEFINE filename, ext, newext, lst STRING
  DEFINE r1 FILEDLG_RECORD
  --CALL fgl_winmessage("Info",sfmt("fglped_saveasdlg %1",fname),"info")
  IF m_qa_saveAsFileName IS NOT NULL THEN
    LET fname = m_qa_saveAsFileName
    LET m_qa_saveAsFileName = NULL
    RETURN fname
  END IF
  IF m_IsNewFile THEN
    LET ext = m_NewFileExt
  ELSE
    LET ext = os.Path.extension(m_srcfile)
  END IF
  IF _isLocal() THEN
    IF fname IS NULL THEN
      LET fname = os.Path.pwd()
    END IF
    LET lst = IIF(ext IS NULL, "*.*", "*." || ext || " *.*")
    CALL ui.Interface.frontCall(
        "standard",
        "saveFile",
        [fname, "Genero file", lst, "Save File"],
        [filename])
  ELSE
    LET r1.title = "Please specify disk file name for the current document"
    IF m_IsFiddle THEN
      LET r1.opt_root_dir = os.Path.pwd()
    END IF
    LET r1.types[1].description = "Genero ", ext, " file"
    LET r1.types[1].suffixes = "*.", ext
    LET r1.types[2].description = "All files (*.*)"
    LET r1.types[2].suffixes = "*.*"
    LET filename = filedlg_save(r1.*)
  END IF
  IF filename IS NULL THEN
    RETURN NULL
  END IF
  CALL log(SFMT("fglped_saveasdlg filename:%1", filename))
  LET newext = os.Path.extension(filename)
  IF newext.getLength() == 0 AND ext.getLength() > 0 THEN
    LET filename = filename, ".", ext
  END IF
  --IF os.Path.exists(filename) THEN
  --  IF NOT _filedlg_mbox_yn("Warning",sfmt("File '%1' already exists, do you want to replace it ?",
  --filename),"question") THEN
  --    RETURN NULL
  --  END IF
  --END IF
  RETURN filename
END FUNCTION

FUNCTION fglped_filedlg()
  DEFINE fname STRING
  DEFINE r1 FILEDLG_RECORD
  IF m_qa_chooseFileName IS NOT NULL THEN
    LET fname = m_qa_chooseFileName
    LET m_qa_chooseFileName = NULL
    RETURN fname
  END IF
  IF _isLocal() THEN
    CALL ui.Interface.frontCall(
        "standard",
        "openfile",
        [os.Path.pwd(), "Form Files", "*.per", "Please choose a form"],
        [fname])
  ELSE
    LET r1.title = "Please choose a file"
    IF m_IsFiddle THEN --sandbox
      LET r1.opt_root_dir = os.Path.pwd()
    END IF
    LET r1.types[1].description = "Genero source files (*.4gl,*.per)"
    LET r1.types[1].suffixes = "*.4gl|*.per"
    LET r1.types[2].description =
        "Genero resource files (*.4st,*.4ad,*.4tm,*.4sm,*.4tb)"
    LET r1.types[2].suffixes = "*.4st|*.4ad|*.4tm|*.4sm|*.4tb"
    LET r1.types[3].description = "All files (*.*)"
    LET r1.types[3].suffixes = "*.*"
    LET fname = filedlg_open(r1.*)
  END IF
  RETURN fname
END FUNCTION

PRIVATE FUNCTION split_src(src)
  DEFINE src, line STRING
  DEFINE tok base.StringTokenizer
  DEFINE linenum INT
  CALL m_orglines.clear()
  LET tok = base.StringTokenizer.createExt(src, "\n", "\\", TRUE)
  LET linenum = 1
  WHILE tok.hasMoreTokens()
    LET line = tok.nextToken()
    LET m_orglines[linenum].line = IIF(line IS NULL, " " CLIPPED, line)
    LET m_orglines[linenum].orgnum = linenum
    LET linenum = linenum + 1
  END WHILE
  {
  LET linenum=m_orglines.getLength()
  IF linenum>1 THEN
    LET line=m_orglines[linenum].line
    IF line.getLength()==0 THEN
      --delete last line containing newline
      CALL m_orglines.deleteElement(linenum)
    END IF
  END IF
  }
END FUNCTION

# syncs m_orglines into m_savedlines
# m_savedline represent the original file
PRIVATE FUNCTION savelines()
  DEFINE i, len INT
  CALL m_savedlines.clear()
  LET len = m_orglines.getLength()
  FOR i = 1 TO len
    LET m_savedlines[i] = m_orglines[i].line
  END FOR
  LET m_modified = FALSE
END FUNCTION

PRIVATE FUNCTION restorelines()
  DEFINE i, len INT
  CALL m_orglines.clear()
  LET len = m_savedlines.getLength()
  FOR i = 1 TO len
    LET m_orglines[i].line = m_savedlines[i]
    LET m_orglines[i].orgnum = i
  END FOR
  LET m_modified = FALSE
END FUNCTION

PRIVATE FUNCTION loadKeywords()
  DEFINE start DATETIME YEAR TO FRACTION(2)
  LET start = CURRENT
  CALL loadKeywordsFor("fgl", "4gl")
  CALL loadKeywordsFor("per", "per")
  CALL log(SFMT("time for loadKeywords:%1", CURRENT - start))
END FUNCTION

#+ looks up the vim syntax files
#+ pre 3.10: $FGLDIR/lib/fgl.vim|per.vim
#+ since 3.10: $FGLDIR/vimfiles/syntax/fgl.vim|per.vim
PRIVATE FUNCTION loadKeywordsFor(vimmode, mode)
  DEFINE vimmode, mode, vimfile, vimfile2 STRING
  DEFINE sep, fgldir, cmdir, templ STRING
  LET cmdir = mydir(my_arg_val(0))
  LET templ = myjoin(cmdir, SFMT("%1.js", mode))
  LET sep = os.Path.separator()
  LET fgldir = fgl_getenv("FGLDIR")
  IF fgldir IS NULL THEN
    CALL err("FGLDIR must be set")
  END IF
  LET vimfile =
      myjoin(fgldir, SFMT("vimfiles%1syntax%2%3.vim", sep, sep, vimmode))
  LET vimfile2 = myjoin(fgldir, SFMT("lib%1%2.vim", sep, vimmode))
  CASE
    WHEN os.Path.exists(vimfile)
      CALL mergekeywords(cmdir, mode, templ, vimfile)
    WHEN os.Path.exists(vimfile2)
      CALL mergekeywords(cmdir, mode, templ, vimfile2)
    OTHERWISE
      CALL err(
          SFMT("Can't find neither %1 nor %2 for %3 keywords",
              vimfile, vimfile2, mode))
  END CASE
END FUNCTION

#+ merges keywords from the vim syntax files
#+ into the codemirror mode template file
PRIVATE FUNCTION mergekeywords(cmdir, mode, templ, vimfile)
  DEFINE cmdir, mode, templ, vimfile STRING
  DEFINE line, keyword, destfile, sep STRING
  DEFINE c, d base.Channel
  DEFINE i INT
  DEFINE keywords DYNAMIC ARRAY OF STRING
  LET sep = os.Path.separator()
  LET c = base.Channel.create()
  CALL c.openFile(vimfile, "r")
  WHILE (line := c.readLine()) IS NOT NULL
    IF line.getIndexOf("syn keyword fglKeyword ", 1) == 1 THEN
      LET keyword = line.subString(24, line.getLength())
      LET keywords[keywords.getLength() + 1] = keyword.trim()
    END IF
  END WHILE
  CALL c.close()
  IF keywords.getLength() = 0 THEN
    CALL err(SFMT("Didn't find any keywords in vim file:%1", vimfile))
  END IF
  CALL c.openFile(templ, "r")
  LET destfile =
      myjoin(
          cmdir,
          SFMT("webcomponents%1fglcm%2customMode%3%4.js", sep, sep, sep, mode))
  LET d = base.Channel.create()
  CALL d.openFile(destfile, "w")
  CALL d.writeLine(
      SFMT("// This file was generated by cm, template: %1", templ))
  CALL d.writeLine("// changes to this file have no effect")
  WHILE (line := c.readLine()) IS NOT NULL
    IF line.getIndexOf("var keywords={};", 1) == 1 THEN
      CALL d.writeLine('    var keywords={')
      CALL d.writeLine(SFMT('       "%1":true', keywords[1]))
      FOR i = 2 TO keywords.getLength()
        CALL d.writeLine(SFMT('      ,"%1":true', keywords[i]))
      END FOR
      CALL d.writeLine('    } //keywords')
    ELSE
      CALL d.writeLine(line)
    END IF
  END WHILE
  CALL c.close()
  CALL d.close()
END FUNCTION

FUNCTION get_program_output(program, merge_stdout_and_stderr)
  DEFINE program STRING
  DEFINE merge_stdout_and_stderr BOOLEAN
  DEFINE tmpName, errName STRING
  DEFINE code INTEGER
  DEFINE ok BOOLEAN
  DEFINE t TEXT
  DEFINE result STRING
  LET tmpName = os.Path.makeTempName()
  IF merge_stdout_and_stderr THEN
    LET program = program, '> "', tmpName, '" 2>&1'
  ELSE
    LET errName = os.Path.makeTempName()
    LET program = program, '> "', tmpName, '" 2>"', errName, '"'
  END IF
  RUN program RETURNING code
  IF code THEN
    LOCATE t IN FILE IIF(merge_stdout_and_stderr, tmpName, errName)
  ELSE
    LOCATE t IN FILE tmpName
    LET ok = TRUE
  END IF
  LET result = t
  CALL os.Path.delete(tmpName) RETURNING code
  IF errName IS NOT NULL THEN
    CALL os.Path.delete(errName) RETURNING code
  END IF
  RETURN ok, result
END FUNCTION

FUNCTION process_make_results(output)
  DEFINE output, line, errfile STRING
  DEFINE tok base.StringTokenizer
  DEFINE i, linenum INT
  CALL compile_arr.clear()
  LET tok = base.StringTokenizer.createExt(output, "\n", "\\", TRUE)
  LET linenum = 1
  WHILE tok.hasMoreTokens()
    LET line = tok.nextToken()
    LET compile_arr[linenum] = IIF(line IS NULL, " " CLIPPED, line)
    LET linenum = linenum + 1
  END WHILE
  CALL initialize_when(TRUE)
  CALL process_compile_errors(NULL, FALSE)
  FOR i = 1 TO m_cmRec.annotations.getLength()
    LET errfile = m_cmRec.annotations[i].errfile
    IF os.Path.exists(errfile) THEN
      IF os.Path.fullPath(errfile) == os.Path.fullPath(m_srcfile) THEN
        --error/warning is in in the current file, just go to the location
        LET m_cmRec.cursor1.* = m_cmRec.annotations[i].from.*
        LET m_cmRec.cursor2.* = m_cmRec.annotations[i].to.*
        CALL flush_cm()
        RETURN TRUE
      ELSE
        CALL doFileOpen(errfile)
        RETURN TRUE
      END IF
    END IF
  END FOR
  RETURN FALSE
END FUNCTION

# merges a given ActionDefaultList into the existing ActionDefaultList
# of the given form
FUNCTION mergeADList(f, adlist)
  DEFINE f ui.Form
  DEFINE adlist, tmpName STRING
  DEFINE fNode, nadlist, nadlist2, nchild om.DomNode
  DEFINE nlist om.NodeList
  LET fNode = f.getNode()
  LET nlist = fNode.selectByTagName("ActionDefaultList")
  IF nlist.getLength() > 0 THEN
    LET nadlist = nlist.item(1)
  END IF
  CALL f.loadActionDefaults(adlist)
  IF nadlist IS NULL THEN
    RETURN
  END IF
  LET nlist = fNode.selectByTagName("ActionDefaultList")
  IF nlist.getLength() > 0 THEN
    LET nadlist2 = nlist.item(1)
  END IF
  WHILE (nchild := nadlist2.getFirstChild()) IS NOT NULL
    CALL nadlist2.removeChild(nchild)
    CALL nadlist.appendChild(nchild)
    LET nchild = nchild.getNext()
  END WHILE
  LET tmpName = os.Path.makeTempName()
  CALL os.Path.delete(tmpName) RETURNING status
  LET tmpName = tmpName, ".4ad"
  CALL log(SFMT("mergeADList tmpName:%1", tmpName))
  CALL nadlist.writeXml(tmpName)
  CALL f.loadActionDefaults(tmpName)
  CALL os.Path.delete(tmpName) RETURNING status
END FUNCTION

FUNCTION mergeTopMenu(f, topmenu)
  DEFINE f ui.Form
  DEFINE topmenu, tmpName STRING
  DEFINE fNode, ntm1, ntm2, nchild om.DomNode
  DEFINE nlist om.NodeList
  LET fNode = f.getNode()
  LET nlist = fNode.selectByTagName("TopMenu")
  IF nlist.getLength() > 0 THEN
    LET ntm1 = nlist.item(1)
  END IF
  CALL f.loadTopMenu(topmenu)
  IF ntm1 IS NULL THEN
    RETURN --there wasn't a top menu previously
  END IF
  LET nlist = fNode.selectByTagName("TopMenu")
  IF nlist.getLength() > 0 THEN
    LET ntm2 = nlist.item(1)
  END IF
  WHILE (nchild := ntm2.getFirstChild()) IS NOT NULL
    CALL ntm2.removeChild(nchild)
    CALL ntm1.appendChild(nchild)
    LET nchild = nchild.getNext()
  END WHILE
  LET tmpName = os.Path.makeTempName()
  CALL os.Path.delete(tmpName) RETURNING status
  LET tmpName = tmpName, ".4tm"
  CALL log(SFMT("mergeTopMenu tmpName:%1", tmpName))
  CALL ntm1.writeXml(tmpName)
  CALL f.loadTopMenu(tmpName)
  CALL os.Path.delete(tmpName) RETURNING status
END FUNCTION

FUNCTION evalOM(om)
  DEFINE om STRING
  --CALL ui.Interface.frontCall("webcomponent","call",["formonly.wc","gmiEmitReceive",om],[])
  --CURRENT WINDOW IS screen
  --DISPLAY "om:",om
  DISPLAY om TO webpreview
  --CALL fgl_dialog_setbuffer(om)
END FUNCTION

FUNCTION getStyleListNode()
  DEFINE root om.DomNode
  DEFINE list om.NodeList
  LET root = ui.Interface.getRootNode()
  LET list = root.selectByTagName("StyleList")
  IF list.getLength() > 0 THEN
    RETURN list.item(1)
  END IF
  RETURN NULL
END FUNCTION

FUNCTION webco2edit()
  DEFINE pNode, pp1, pp2, ch om.DomNode
  LET pNode = nodeForPreview()
  LET ch = pNode.getFirstChild()
  IF ch.getTagName() == "WebComponent" THEN
    IF m_dummyFF IS NULL THEN
      LET m_dummyFF =
          nodeFromPathChecked(
              getCurrentFormNode(), '//FormField[@name="formonly.edummy"]')
      CALL m_dummyFF.setAttribute("colName", "webpreview")
      CALL m_dummyFF.setAttribute("name", "formonly.webpreview")
      LET pp2 = m_dummyFF.getParent()
      CALL pp2.removeChild(m_dummyFF)
    END IF
    --DISPLAY "--->mv Webco to tmp"
    LET m_previewFF = pNode
    LET pp1 = pNode.getParent()
    CALL pp1.removeChild(m_previewFF)
    CALL pp1.appendChild(m_dummyFF)
  END IF
END FUNCTION

FUNCTION edit2webco()
  DEFINE pNode, ch, pp1 om.DomNode
  LET pNode = nodeForPreview()
  LET ch = pNode.getFirstChild()
  IF ch.getTagName() == "Edit" THEN
    --DISPLAY "--->mv Webco back into form"
    _ASSERT(m_previewFF IS NOT NULL)
    LET pp1 = pNode.getParent()
    CALL pp1.replaceChild(m_previewFF, pNode)
    LET m_previewFF = NULL
  END IF
END FUNCTION

FUNCTION initGBC()
  DEFINE tmp42f STRING
  LET m_gbcInitSeen = TRUE
  IF NOT isPERFile(m_tmpname) THEN
    CALL webco2edit()
  ELSE
    CALL edit2webco()
    LET tmp42f = m_lastCompiledPER
    LET tmp42f = tmp42f.subString(1, tmp42f.getLength() - 4)
    CALL buildX(tmp42f)
  END IF
END FUNCTION

FUNCTION buildX(frmName)
  DEFINE frmName STRING
  DEFINE om STRING
  DEFINE root, origList, p om.DomNode
  DEFINE win ui.Window
  DEFINE f ui.Form
  --DISPLAY "buildX:", frmName
  LET origList = getStyleListNode()
  LET p = origList.getParent()
  OPEN WINDOW _formpreview WITH FORM frmName
  {
  CALL p.removeChild(origList)
  CALL ui.Interface.loadStyles("custom")
  }
  LET win = ui.Window.getCurrent()
  LET f = win.getForm()
  IF m_omCount == 0 THEN
    LET root = ui.Interface.getRootNode()
  ELSE
    LET root = win.getNode()
  END IF
  CALL removeWebComponentType(f.getNode())
  LET om = buildOM(root, m_lastWindowId)
  --DISPLAY "om:",om
  {
  LET newList=getStyleListNode()
  CALL p.replaceChild(origList,newList)
  }
  CLOSE WINDOW _formpreview
  CALL evalOM(om)
END FUNCTION

FUNCTION buildOM(node, removeId)
  DEFINE node, parentNode om.DomNode
  DEFINE removeId, parentId INT
  DEFINE b base.StringBuffer
  LET b = base.StringBuffer.create()
  CALL b.append(SFMT("om %1 {", m_omCount))
  IF removeId <> 0 THEN
    CALL b.append(SFMT("{rn %1}", removeId))
  END IF
  LET parentNode = node.getParent()
  LET parentId = IIF(parentNode IS NULL, 0, parentNode.getId())
  CALL b.append(SFMT("{an %1 ", parentId))
  CALL buildListInt(node, b)
  CALL b.append("}")
  CALL b.append("}\n")
  LET m_omCount = m_omCount + 1
  --DISPLAY "buildOM:", b.toString()
  RETURN b.toString()
END FUNCTION

FUNCTION buildListInt(n, b)
  DEFINE n, c om.DomNode
  DEFINE b, cb base.StringBuffer
  DEFINE name, attr, tag, value STRING
  DEFINE i, cnt INT
  LET tag = n.getTagName()
  CASE
    WHEN tag == "Window"
      LET name = n.getAttribute("name")
      IF name.equals("_formpreview") THEN
        --DISPLAY "our window"
        LET m_lastWindowId = n.getId()
      ELSE
        --DISPLAY "omit WIndow:", name
        RETURN
      END IF
      --WHEN tag=="Form"
      --  LET m_lastFormId=n.getId()
    WHEN tag == "Message"
      --DISPLAY "ignore message"
      RETURN
  END CASE

  --IF tag=="Message" OR tag=="ActionDefaultList" OR tag=="ImageFonts" OR tag=="StyleList" THEN
  --  RETURN
  --END IF
  CALL b.append(SFMT("%1 %2 {", n.getTagName(), n.getId()))
  LET cnt = n.getAttributesCount()
  FOR i = 1 TO cnt
    LET attr = n.getAttributeName(i)
    LET value = n.getAttributeValue(i)
    CASE
      WHEN tag == "Window" AND attr == "parent"
        CONTINUE FOR
      WHEN tag == "UserInterface" AND attr == "runtimeStatus"
        LET value = "processing" --avoid focusing
    END CASE
    CALL b.append(SFMT('{%1 "%2"', attr, value))
    CALL b.append(IIF(i <> cnt, "} ", "}"))
  END FOR
  CALL b.append("}")
  CALL b.append(" {")
  --IF tag=="ActionDefaultList" OR (NOT parentTag.equals("Form") AND tag=="StyleList") THEN
  IF tag == "ActionDefaultList" THEN
    CALL b.append("}")
    RETURN
  END IF
  LET c = n.getFirstChild()
  WHILE c IS NOT NULL
    LET cb = base.StringBuffer.create()
    CALL buildListInt(c, cb)
    LET c = c.getNext()
    IF cb.getLength() > 0 THEN
      CALL b.append("{")
      CALL b.append(cb.toString())
      CALL b.append(IIF(c IS NOT NULL, "} ", "}"))
    END IF
  END WHILE
  CALL b.append("}")
END FUNCTION

FUNCTION assert(assertion_body)
  DEFINE assertion_body STRING
  CALL to_stderr(
      SFMT("ERROR: assertion failed:%1\nstack:\n%2",
          assertion_body, base.Application.getStackTrace()))
  EXIT PROGRAM 1
END FUNCTION

FUNCTION assert_with_msg(assertion_body, msg)
  DEFINE assertion_body, msg STRING
  CALL to_stderr(
      SFMT("ERROR: assertion failed:%1,%2\nstack:\n%3",
          assertion_body, msg, base.Application.getStackTrace()))
  EXIT PROGRAM 1
END FUNCTION

FUNCTION to_stderr(s)
  DEFINE s STRING
  DEFINE c base.Channel
  LET c = base.Channel.create()
  CALL c.openFile("<stderr>", "w")
  CALL c.writeLine(s)
END FUNCTION

FUNCTION readFileIntoString(fileName)
  DEFINE fileName STRING
  DEFINE content STRING
  DEFINE t TEXT
  _ASSERT(os.Path.exists(fileName))
  LOCATE t IN FILE fileName
  LET content = t
  RETURN content
END FUNCTION

FUNCTION setQAChooseFileName(fname)
  DEFINE fname STRING
  LET m_qa_chooseFileName = fname
END FUNCTION

FUNCTION qaSendInput(txt)
  DEFINE txt STRING
  CALL ui.Interface.frontCall(
      "webcomponent", "call", ["formonly.cm", "qaSendInput", txt], [])
END FUNCTION

FUNCTION qaReadFile(filename)
  DEFINE filename STRING
  RETURN readFileIntoString(filename)
END FUNCTION

FUNCTION qaGetInternalBufferJSON()
  RETURN util.JSON.stringify(m_orglines)
END FUNCTION

FUNCTION qaSendAction(actionName)
  DEFINE actionName STRING
  CALL ui.Interface.frontCall(
      "webcomponent", "call", ["formonly.cm", "qaSendAction", actionName], [])
END FUNCTION

FUNCTION getQueryDict(fn STRING) RETURNS(STRING, TStringDict)
  DEFINE q, pstr, name, value STRING
  DEFINE qidx, idx INT
  DEFINE tok base.StringTokenizer
  DEFINE d TStringDict
  LET qidx = fn.getIndexOf("?", 1)
  IF qidx == 0 THEN
    RETURN fn, d
  END IF
  LET q = fn.subString(qidx + 1, fn.getLength())
  LET tok = base.StringTokenizer.create(q, "&")
  WHILE tok.hasMoreTokens()
    LET pstr = tok.nextToken()
    IF (idx := pstr.getIndexOf("=", 1)) != 0 THEN
      LET name = pstr.subString(1, idx - 1)
      LET value = pstr.subString(idx + 1, pstr.getLength())
      LET d[name] = value
    END IF
  END WHILE
  --DISPLAY "getQueryDict:", util.JSON.stringify(d)
  RETURN fn.subString(1, qidx - 1), d
END FUNCTION

FUNCTION getLastModified(fn STRING)
  DEFINE m INT
  LET m = util.Datetime.toSecondsSinceEpoch(os.Path.mtime(fn))
  RETURN m
END FUNCTION

FUNCTION formatUrl(fn STRING, d TStringDict)
  DEFINE i INT
  DEFINE keys DYNAMIC ARRAY OF STRING
  DEFINE o, key STRING
  LET o = fn
  LET keys = d.getKeys()
  FOR i = 1 TO keys.getLength()
    LET o = o, IIF(i == 1, "?", "&")
    LET key = keys[i]
    LET o = o, key, "=", d[key]
  END FOR
  RETURN o
END FUNCTION

FUNCTION findScriptOrLink(l STRING, dir STRING)
  DEFINE i1, i2, i3, i4, i5 INT
  DEFINE fn, fn2, fn3 STRING
  DEFINE d TStringDict
  IF ((i1 := l.getIndexOf("<script", 1)) > 0
          OR (i1 := l.getIndexOf("<link", 1)))
      AND ((i2 := l.getIndexOf("src", i1)) > 0
          OR (i2 := l.getIndexOf("href", i1)) > 0)
      AND (i3 := l.getIndexOf("=", i2)) > 0
      AND (i4 := l.getIndexOf('"', i3)) > 0
      AND (i5 := l.getIndexOf('"', i4 + 1)) > 0 THEN
    LET fn = l.subString(i4 + 1, i5 - 1)
    --DISPLAY "fn:'",fn,"'"
    CALL getQueryDict(fn) RETURNING fn, d
    LET fn2 = os.Path.join(dir, fn)
    IF os.Path.exists(fn2) THEN
      LET d["s"] = os.Path.size(fn2)
      LET d["t"] = getLastModified(fn2)
      LET fn3 = formatUrl(fn, d)
      LET l = l.subString(1, i4), fn3, l.subString(i5, l.getLength())
      --DISPLAY "did format l:", l
    ELSE
      DISPLAY "fn2:", fn2, " does not exists"
    END IF
  END IF
  RETURN l
END FUNCTION

FUNCTION fileContentEqual(f1 STRING, f2 STRING) RETURNS BOOLEAN
  DEFINE code INT
  IF fgl_getenv("WINDIR") IS NOT NULL OR fgl_getenv("windir") IS NOT NULL THEN
    RUN SFMT("fc %1 %2", f1, f2) RETURNING code
  ELSE
    RUN SFMT("diff %1 %2", f1, f2) RETURNING code
  END IF
  RETURN code == 0
END FUNCTION

--puts size and time queries into the assets referenced by the webco to enable caching
FUNCTION patch_webco(compo STRING)
  DEFINE ch, co base.Channel
  DEFINE line, dir, fn, tmp STRING
  LET fn = "webcomponents/", compo, "/", compo, ".html"
  LET fn = os.Path.join(os.Path.dirName(arg_val(0)), fn)
  IF NOT os.Path.exists(fn) THEN
    LET fn = compo, ".html"
  END IF
  LET dir = os.Path.dirName(fn)
  --DISPLAY "patch_webco:", fn
  LET ch = base.Channel.create()
  LET co = base.Channel.create()
  LET tmp = os.Path.makeTempName()
  CALL co.openFile(tmp, "w")
  CALL ch.openFile(fn, "r")
  WHILE (line := ch.readLine()) IS NOT NULL
    --LET line=line.trimWhiteSpace()
    LET line = findScriptOrLink(line, dir)
    CALL co.writeLine(line)
  END WHILE
  CALL ch.close()
  CALL co.close()
  IF os.Path.size(fn) <> os.Path.size(tmp)
      OR (NOT file_equal(fn, tmp, FALSE)) THEN
    CALL log(
        SFMT("copy:%1 (%2 bytes) over:%3 (%4 bytes)",
            tmp, os.Path.size(tmp), fn, os.Path.size(fn)))
    CALL os.Path.copy(tmp, fn) RETURNING status
    CALL os.Path.delete(tmp) RETURNING status
  ELSE
    --DISPLAY "file equal:", tmp, " to:", fn
  END IF
END FUNCTION

FUNCTION cpChecked(src, dest)
  DEFINE src, dest STRING
  IF os.Path.size(src) == os.Path.size(dest)
      AND file_equal(src, dest, FALSE) THEN
    --DISPLAY sfmt("cpChecked: '%1' already copied to '%2'",src,dest)
    RETURN
  END IF
  _ASSERT(src.getIndexOf("..", 1) == 0)
  _ASSERT(dest.getIndexOf("..", 1) == 0)
  IF NOT os.Path.copy(src, dest) THEN
    CALL myErr(SFMT("cpChecked: can't copy '%1' to '%2'", src, dest))
  ELSE
    --DISPLAY sfmt("cpChecked '%1'->'%2'",src,dest)
  END IF
END FUNCTION

FUNCTION file_equal_txtfile(f1, f2)
  DEFINE f1, f2 STRING
  DEFINE t1, t2 TEXT
  DEFINE s1, s2 STRING
  LOCATE t1 IN FILE f1
  LET s1 = t1
  LOCATE t2 IN FILE f2
  LET s2 = t2
  --DISPLAY "file_equal_txtfile: ",f1," ",f2
  IF NOT s1.equals(s2) THEN
    --DISPLAY "not equal:", f1, "<>", f2
    IF NOT isWin() THEN
      RUN SFMT("diff %1 %2", quote(f1), quote(f2))
    END IF
    RETURN FALSE
  END IF
  RETURN TRUE
END FUNCTION

FUNCTION file_equal(f1, f2, ignorecase)
  DEFINE f1, f2 STRING
  DEFINE ignorecase BOOLEAN
  DEFINE cmd, tool, opt, ext STRING
  DEFINE code INTEGER
  IF NOT os.Path.exists(f1)
      OR NOT os.Path.exists(f2)
      OR os.Path.size(f1) <> os.Path.size(f2) THEN
    RETURN FALSE
  END IF
  LET ext = os.Path.extension(f1)
  IF (NOT ignorecase)
      AND (ext == "js"
          OR ext == "txt"
          OR ext == "html"
          OR ext == "css"
          OR ext == "4gl"
          OR ext == "per"
          OR ext == "42f"
          OR ext == "4st"
          OR ext == "4ad"
          OR ext == "4tb"
          OR ext == "svg") THEN
    RETURN file_equal_txtfile(f1, f2)
  END IF
  --DISPLAY "ignore case:",ignorecase,",ext:",ext
  IF ignorecase THEN
    LET opt = IIF(isWin(), "/c", "-i")
  END IF
  LET tool = IIF(isWin(), "fc", "diff")
  LET cmd = SFMT("%1 %2 %3 %4", tool, opt, quote(f1), quote(f2))
  RUN cmd RETURNING code
  RETURN (code == 0)
END FUNCTION

FUNCTION cpGBCAssets2Dest(dir, destdir)
  DEFINE dir, destdir STRING
  DEFINE dh INT
  DEFINE fname, dest, fullName, ext STRING
  LET dh = os.Path.dirOpen(dir)
  IF dh == 0 THEN
    RETURN
  END IF
  WHILE (fname := os.Path.dirNext(dh)) IS NOT NULL
    IF fname IS NULL
        OR fname == "."
        OR fname == ".."
        OR fname == "webcomponents" THEN
      CONTINUE WHILE
    END IF
    LET ext = os.Path.extension(fname)
    IF ext == "gz" THEN
      CONTINUE WHILE
    END IF
    LET fullName = join(dir, fname)
    LET dest = join(destdir, fname)
    --DISPLAY "fname:",fname,",fullName:",fullName,",dest:",dest
    IF os.Path.isDirectory(fullName) THEN
      CALL mkdir(dest)
      CALL cpGBCAssets2Dest(fullName, dest)
    ELSE
      --IF NOT fname.equals("gbc.bootstrap.js") THEN
      CALL cpChecked(fullName, dest)
      --END IF
    END IF
  END WHILE
  CALL os.Path.dirClose(dh)
END FUNCTION

PRIVATE FUNCTION _findGBCIn(dirname)
  DEFINE dirname STRING
  IF os.Path.exists(os.Path.join(dirname, "index.html"))
      AND os.Path.exists(os.Path.join(dirname, "index.html"))
      AND os.Path.exists(os.Path.join(dirname, "VERSION")) THEN
    LET m_gbcdir = dirname
    --DISPLAY "m_gbcdir:'", m_gbcdir, "'"
    RETURN TRUE
  END IF
  RETURN FALSE
END FUNCTION

FUNCTION checkGBCAvailable()
  IF NOT _findGBCIn(os.Path.join(os.Path.pwd(), "gbc")) THEN
    IF NOT _findGBCIn(fgl_getenv("FGLGBCDIR")) THEN
      IF NOT _findGBCIn(
          os.Path.join(fgl_getenv("FGLDIR"), "web_utilities/gbc/gbc")) THEN
        CALL myErr(
            "Can't find a GBC in <pwd>/gbc, fgl_getenv('FGLGBCDIR') or $FGLDIR/web_utilities/gbc/gbc")
      END IF
    END IF
  END IF
END FUNCTION

FUNCTION myErr(errstr STRING)
  DEFINE ch base.Channel
  LET ch = base.Channel.create()
  CALL ch.openFile("<stderr>", "w")
  CALL ch.writeLine(
      SFMT("ERROR:%1 stack:\n%2", errstr, base.Application.getStackTrace()))
  CALL ch.close()
  EXIT PROGRAM 1
END FUNCTION

FUNCTION mkdir(d)
  DEFINE d STRING
  IF NOT os.Path.exists(d) THEN
    _ASSERT(os.Path.mkdir(d) == TRUE)
  END IF
END FUNCTION

FUNCTION mkdirp(basedir, path)
  DEFINE basedir, path, part STRING
  DEFINE tok base.StringTokenizer
  LET tok = base.StringTokenizer.create(path, "/")
  LET part = basedir
  WHILE tok.hasMoreTokens()
    LET part = os.Path.join(part, tok.nextToken())
    IF NOT os.Path.exists(part) THEN
      IF NOT os.Path.mkdir(part) THEN
        CALL myErr(SFMT("can't create directory:%1", part))
      ELSE
        --DISPLAY "did mkdir:",part
      END IF
    END IF
    --LET part=part,os.Path.separator()
  END WHILE
END FUNCTION

FUNCTION fileMustExist(name, mustbelink)
  DEFINE name STRING
  DEFINE mustbelink BOOLEAN
  IF NOT os.Path.exists(name) THEN
    CALL myErr(SFMT("can't find '%1'", name))
  END IF
  IF mustbelink AND NOT os.Path.isLink(name) THEN
    CALL myErr(SFMT("'%1' must be a link", name))
  END IF
END FUNCTION

FUNCTION replacechar(fname, chartoreplace, replacechar)
  DEFINE fname, chartoreplace, replacechar STRING
  DEFINE buf base.StringBuffer
  DEFINE prev, idx INTEGER
  LET buf = base.StringBuffer.create()
  CALL buf.append(fname)
  LET prev = 1
  WHILE (idx := buf.getIndexOf(chartoreplace, prev)) <> 0
    CALL buf.replaceAt(idx, 1, replacechar)
    LET prev = idx
  END WHILE
  RETURN buf.toString()
END FUNCTION

FUNCTION nativePath(fname)
  DEFINE fname STRING
  RETURN IIF(isWin(), replacechar(fname, "/", "\\"), fname)
END FUNCTION

PRIVATE FUNCTION join(arg1, arg2)
  DEFINE arg1, arg2 STRING
  RETURN os.Path.join(arg1, arg2)
END FUNCTION

FUNCTION already_quoted(path)
  DEFINE path, first, last STRING
  LET first = NVL(path.getCharAt(1), "NULL")
  LET last = NVL(path.getCharAt(path.getLength()), "NULL")
  IF isWin() THEN
    RETURN (first == '"' AND last == '"')
  END IF
  RETURN (first == "'" AND last == "'") OR (first == '"' AND last == '"')
END FUNCTION

FUNCTION quote(path)
  DEFINE path STRING
  IF path.getIndexOf(" ", 1) > 0 THEN
    IF NOT already_quoted(path) THEN
      LET path = '"', path, '"'
    END IF
  ELSE
    IF already_quoted(path) AND isWin() THEN --remove quotes(Windows)
      LET path = path.subString(2, path.getLength() - 1)
    END IF
  END IF
  RETURN path
END FUNCTION

FUNCTION nodeDesc(n om.DomNode)
  DEFINE i, len INT
  DEFINE sb base.StringBuffer
  LET sb = base.StringBuffer.create()
  CALL sb.append(n.getTagName())
  LET len = n.getAttributesCount()
  FOR i = 1 TO len
    CALL sb.append(
        SFMT(" %1='%2'", n.getAttributeName(i), n.getAttributeValue(i)))
  END FOR
  RETURN sb.toString()
END FUNCTION

FUNCTION printOmInt(n om.DomNode, indent INT)
  DEFINE x STRING
  DEFINE ch om.DomNode
  DEFINE i INT
  FOR i = 1 TO indent
    LET x = x, " "
  END FOR
  LET x = x, nodeDesc(n)
  --LET x = x
  DISPLAY x
  LET ch = n.getFirstChild()
  WHILE ch IS NOT NULL
    CALL printOmInt(ch, indent + 2)
    LET ch = ch.getNext()
  END WHILE
END FUNCTION

FUNCTION myExit(where, code)
  DEFINE where STRING
  DEFINE code INT
  DISPLAY "EXIT PROGRAM from:", where, ", code:", code
  EXIT PROGRAM code
END FUNCTION
