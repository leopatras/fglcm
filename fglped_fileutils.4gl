--file functions
--this module contains useful functions for manipulating files and filenames in
--a cross platform fashion
IMPORT os

--keeps the last error message
DEFINE file_errstr STRING

--returns the OS specific separator character in file names
FUNCTION file_get_separator()
  IF file_on_windows() THEN
    RETURN "\\"
  ELSE
    RETURN "/"
  END IF
END FUNCTION

--tries to find a slash or backlash
--in a given filename
FUNCTION file_get_separator_of(fname)
  DEFINE fname,sep String
  IF fname.getIndexOf("/",1) <> 0 THEN
    LET sep="/"
  ELSE IF fname.getIndexOf("\\",1) <> 0 THEN
    LET sep="\\"
  END IF
  END IF
  RETURN sep
END FUNCTION

--returns the separator character for path environment variables
--such as PATH or DBPATH
FUNCTION file_get_pathvar_separator()
  IF file_on_windows() THEN
    RETURN ";"
  ELSE
    RETURN ":"
  END IF
END FUNCTION

--computes a short filename from a long filename
FUNCTION file_get_short_filename(filepath)
  DEFINE filepath STRING
  RETURN os.Path.basename(filepath)
END FUNCTION

--gives back the directory portion of a filename
FUNCTION file_get_dirname(filename)
  DEFINE filename STRING
  DEFINE dirname STRING
  LET dirname=os.Path.dirname(filename)
  IF dirname IS NULL THEN
    LET dirname="."
  END IF
  RETURN dirname
END FUNCTION

FUNCTION file_exists(filename)
  DEFINE filename STRING
  RETURN os.Path.exists(filename)
END FUNCTION

FUNCTION file_is_dir(filename)
  DEFINE filename STRING
  RETURN os.Path.isdirectory(filename)
END FUNCTION

FUNCTION file_mkdir(dirname)
  DEFINE dirname STRING
  DEFINE code STRING
  IF file_on_windows() THEN
    RUN sfmt("mkdir \"%1\"",dirname) RETURNING code
  ELSE 
    RUN sfmt("mkdir %1",dirname) RETURNING code
  END IF
  IF code THEN
    LET file_errstr="failed to make directory "||dirname
    RETURN 0
  END IF
  RETURN 1
END FUNCTION

FUNCTION file_get_last_error()
  RETURN file_errstr
END FUNCTION

FUNCTION file_get_home_dir()
  DEFINE home STRING
  IF file_on_windows() THEN
    LET home=fgl_getenv("HOMEDRIVE"),fgl_getenv("HOMEPATH")
  ELSE
    LET home=fgl_getenv("HOME")
  END IF
  RETURN home
END FUNCTION

FUNCTION file_join(path,filename)
  DEFINE path STRING 
  DEFINE filename STRING
  RETURN os.Path.join(path,filename)
END FUNCTION

FUNCTION file_on_windows()
  IF fgl_getenv("WINDIR") IS NULL THEN
    RETURN 0
  ELSE
    RETURN 1
  END IF
END FUNCTION

FUNCTION file_get_output_string(cmd)
  DEFINE cmd STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE i,len INT
  DEFINE buf base.StringBuffer
  LET buf=base.StringBuffer.create()
  CALL file_get_output(cmd,arr)
  LET len=arr.getLength()
  FOR i=1 TO len
    CALL buf.append(arr[i])
    IF i<>len THEN
      CALL buf.append("\n")
    END IF
  END FOR
  RETURN buf.toString()
END FUNCTION

FUNCTION file_get_output(program,arr)
  DEFINE program,linestr STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE mystatus,idx INTEGER
  DEFINE c base.Channel
  LET c = base.channel.create()
  CALL c.setDelimiter("")
  WHENEVER ERROR CONTINUE
  CALL c.openpipe(program,"r")
  LET mystatus=status
  WHENEVER ERROR STOP
  --DISPLAY "file_get_output:",program
  IF mystatus THEN
    DISPLAY "error in file_get_output(program,arr)"
    --LET file_errstr=err_get(mystatus)
    RETURN
  END IF
  --DISPLAY "file_get_output:",program
  CALL arr.clear()
  WHILE (linestr:=c.readline()) IS NOT NULL
    LET idx=idx+1
    --DISPLAY "LINE ",idx,"=",linestr
    LET arr[idx]=linestr
  END WHILE
  CALL c.close()
END FUNCTION

{
FUNCTION file_get_output(program,arr)
  DEFINE program,linestr STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE mystatus,idx INTEGER
  DEFINE c base.Channel
  LET c = base.channel.create()
  CALL c.setDelimiter("")
  WHENEVER ERROR CONTINUE
  CALL c.openpipe(program,"r")
  LET mystatus=status
  WHENEVER ERROR STOP
  --DISPLAY "file_get_output:",program
  IF mystatus THEN
    DISPLAY "error in file_get_output(program,arr)"
    LET file_errstr=err_get(mystatus)
    RETURN 0
  END IF
  --DISPLAY "file_get_output:",program
  CALL arr.clear()
  WHILE (linestr:=c.readline()) IS NOT NULL
    LET idx=idx+1
    --DISPLAY "LINE ",idx,"=",linestr
    LET arr[idx]=linestr
  END WHILE
  CALL c.close()
  RETURN 1
END FUNCTION
}

FUNCTION file_start_output(program)
  DEFINE program STRING
  DEFINE mystatus INTEGER
  DEFINE c base.Channel
  LET c = base.channel.create()
  CALL c.setDelimiter("")
  WHENEVER ERROR CONTINUE
  CALL c.openpipe(program,"r")
  LET mystatus=status
  WHENEVER ERROR STOP
  IF mystatus THEN
    LET file_errstr=err_get(mystatus)
    RETURN NULL
  END IF
  RETURN c
END FUNCTION

--returns a string with the current working directory
FUNCTION file_pwd()
  RETURN os.Path.pwd()
END FUNCTION

FUNCTION file_copy(src,dest)
  DEFINE src,dest STRING
  DEFINE cmd STRING
  DEFINE code INTEGER
  IF file_on_windows() THEN
    LET cmd=sfmt("copy \"%1\" \"%2\" >NUL ",src,dest)
  ELSE
    LET cmd=sfmt("cp %1 %2",src,dest)
  END IF
  RUN cmd RETURNING code
  IF code THEN
    LET file_errstr="failed to copy ",src," to ",dest
    RETURN 0
  END IF
  RETURN 1
END FUNCTION

FUNCTION file_get_dir_list(dirname,arr,pattern,complete_path,onlydirs)
  DEFINE dirname STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  DEFINE pattern,diropt STRING
  DEFINE i,len,onlydirs INTEGER
  DEFINE complete_path INTEGER
  DEFINE cmd STRING
  IF file_on_windows() THEN
    IF onlydirs THEN
      LET diropt="/AD"
    END IF
    IF dirname IS NULL THEN
      LET cmd=sfmt("dir /B %1 ",diropt)
    ELSE
      LET cmd=sfmt("dir /B %1 \"%2\"",diropt,dirname)
    END IF
  ELSE
    IF onlydirs THEN
      LET diropt="-d"
    ELSE
      LET diropt="-a"
    END IF
    LET cmd=sfmt("ls %1 %2",diropt,dirname)
  END IF
  IF pattern IS NOT NULL THEN
    IF dirname IS NULL THEN
      LET cmd=cmd,pattern
    ELSE
      LET cmd=file_join(cmd,pattern)
    END IF
  END IF
  DISPLAY "cmd is:",cmd
  CALL file_get_output(cmd,arr)
  LET len=arr.getLength()
  FOR i=1 TO len
    IF complete_path THEN
      IF file_get_short_filename(arr[i])==arr[i] THEN
        LET arr[i]=file_join(dirname,arr[i])
      END IF
    ELSE
      LET arr[i]=file_get_short_filename(arr[i])
    END IF
  END FOR
  RETURN 1
END FUNCTION

--gives back the extension (plus point)
--sample file_extension("foo/hallo.4gl") gives ".4gl"
FUNCTION file_extension(filename)
  DEFINE filename STRING
  DEFINE extension STRING
  LET extension=os.Path.extension(filename)
  IF extension IS NOT NULL THEN
    LET extension=".",extension
  END IF
  RETURN extension
END FUNCTION

--returns back the basefilename without extension if
--called with delete_from_right with NULL
--otherwise the function tries to subtract the first match of
--delete_from_right part from the right side of the string

--sample : file_basename("foo/hallo.4gl",NULL)  gives "foo/hallo"
--sample : file_basename("foo/hallo.4gl",".4gl") gives "foo/hallo"
--sample : file_basename("foo/hallo.4gl",".4g")  gives "foo/hallo" !!
--sample : file_basename("foo/hallo.tmp.4gl",".tmp.4gl")  gives "foo/hallo" !!

FUNCTION file_basename(filename,delete_from_right)
  DEFINE filename STRING
  DEFINE delete_from_right STRING
--if the delete string is NULL we start from right an cut the extension
--plus dot separator
  DEFINE baseName STRING
  DEFINE startIdx,i,foundIdx INTEGER
  LET baseName=filename
  IF delete_from_right IS NULL THEN
    FOR i=filename.getLength() TO 1 STEP -1
      IF i<>1 AND fileName.getCharAt(i)="." THEN
        LET baseName=filename.subString(1,i-1)
        EXIT FOR
      END IF
    END FOR
  ELSE
    LET startIdx=filename.getLength()-delete_from_right.getLength()
    FOR i=startIdx TO 1 STEP -1
      LET foundIdx=fileName.getIndexOf(delete_from_right,i)
      IF foundIdx>0 THEN
        LET baseName=fileName.subString(1,foundIdx-1)
        EXIT FOR
      END IF
    END FOR
  END IF
  RETURN baseName
END FUNCTION

FUNCTION file_delete(filename)
  DEFINE filename STRING
  DEFINE ret INT
  LET ret=os.Path.delete(filename) 
  --DISPLAY "file_delete of '",filename,"' returns:",ret
  RETURN ret
END FUNCTION

FUNCTION file_replacechar(fname,chartoreplace,replacechar)
  DEFINE fname,chartoreplace,replacechar STRING
  DEFINE buf base.StringBuffer
  DEFINE prev,idx INTEGER
  LET buf=base.StringBuffer.create()
  CALL buf.append(fname)
  LET prev=1
  WHILE (idx:=buf.getIndexOf(chartoreplace,prev)) <> 0
    CALL buf.replaceAt(idx,1,replacechar)
    LET prev=idx
  END WHILE
  RETURN buf.toString()
END FUNCTION

FUNCTION file_slash2backslash(fname)
  DEFINE fname STRING
  RETURN file_replacechar(fname,"/","\\")
END FUNCTION

FUNCTION file_backslash2slash(fname)
  DEFINE fname STRING
  RETURN file_replacechar(fname,"\\","/")
END FUNCTION

--normalizes a given directory name
--example /home/foo/bar/../spong -> /home/foo/spong
FUNCTION file_normalize_dir(fname)
  DEFINE fname STRING
  DEFINE cmd STRING
  DEFINE arr DYNAMIC ARRAY OF STRING
  IF NOT file_is_dir(fname) THEN
    RETURN fname
  END IF
  IF fgl_getenv("WINDIR") IS NOT NULL THEN
    LET cmd="cd ",fname,"&&cd"
  ELSE
    LET cmd="cd \"",fname,"\"&&pwd"
  END IF
  CALL file_get_output(cmd,arr)
  RETURN arr[1]
END FUNCTION

FUNCTION is4GLFile(fname)
  DEFINE fname,ext STRING
  LET ext=os.Path.extension(fname)
  IF ext IS NULL THEN
    RETURN FALSE
  END IF
  RETURN ext=="4gl"
END FUNCTION

FUNCTION isPERFile(fname)
  DEFINE fname,ext STRING
  LET ext=os.Path.extension(fname)
  IF ext IS NULL THEN
    RETURN FALSE
  END IF
  RETURN ext=="per"
END FUNCTION

FUNCTION is4GLOrPerFile(fname)
  DEFINE fname STRING
  RETURN is4GLFile(fname) OR isPERFile(fname) 
END FUNCTION
