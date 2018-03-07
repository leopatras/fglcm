#mixes the content of keywords.js into 4gl.js/per.js
BEGIN { idx=0;output_once=1;while (getline < "keywords.js") { f[idx++]=$0;} }
/^var keywords/ , /^\}\/\/keywords/ { 
  inmatch=1;
  if (output_once==1) {
    output_once=0;
    for (i=0;i<idx;i++) {
      print(f[i]);
    }
  }
} 
{ 
  if (inmatch==1) {
    inmatch=0;
  } else { 
    print($0);
  }
}
