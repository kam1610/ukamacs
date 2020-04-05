# -*- coding: japanese-cp932 -*-
## SARS2の出力するSakuraScriptを整形
## \0 or \1が切り替わるタイミング，または\n出現時に
## "/"をつけて改行．
## また，文字列前後にクォーテーションを付加
$KCODE= "s";
require "jcode";

#scr= ARGV[0]; # 標準入力
buf= ""; # 出力バッファ
state= "norm"; # 標準文字・エスケープ文字 

open("talk_draft.txt"){|file|
  while line= file.gets;
    scr= line;
    # 空白行はスキップ
    if(scr !=~ /^\s+$/)
    # 一文字ずつチェック
    # (ラストの一個手前の文字まで)
    scr= scr.split("");
    0.upto(scr.length - 2){|i|
      if(scr[i] == "\\")
        # scr[i+1]がn or \dならば改行付加．
        if(scr[i+1] =~ /[\duh]/)
          buf+= " /\n  ";
        elsif(scr[i+1] == "n")
          buf+= "\\n /\n";
          scr[i]= "";
          scr[i+1]= "";
        elsif(scr[i+1] == "e")
          buf+= "\\e \n\n";
          scr[i]= "";
          scr[i+1]= "";
        end
      end
      buf+= scr[i];
    }
    end
  end  
}


print buf;
