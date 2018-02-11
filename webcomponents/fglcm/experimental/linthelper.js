//we hack into the linter addon by defining a helper module
(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
"use strict";

CodeMirror.registerHelper("lint", "4gl", function(text, options) {
  var found = [];
  if (window.m_annotations===undefined) {
    if (window.console) {
        window.console.error("Error: window.m_annotations not defined, CodeMirror annotations cannot run.");
    }
    return [];
  }
  return window.m_annotations;
});

});
