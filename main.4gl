MAIN
  DEFINE a INT
  DEFINE b INT
  OPEN FORM f FROM "main"
  DISPLAY FORM f
  MENU "Hello"
    COMMAND "saaa"
      EXIT MENU
    COMMAND "Exit"
      EXIT MENU
  END MENU
  LET a=5
  LET b=4
  DISPLAY "bar"
END MAIN
