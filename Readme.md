# ukamacs

  - EmacsのバッファにGhostのトークを表示します．また，ダブルクリックなどのインタラクションをキーストロークで実現します．
  
  - イベントでのデモ展示を目的として，以下の機能に絞って動作確認しています．
    - OnSecondChangeイベントによるランダムトーク
    - ダブルクリックによるメニュー表示とランダムトーク
  
  - ほかは，，，ごめん,,

# Demo

  ![demo](img/demo.gif)

# インストール & 設定

  1. ukamacs/ 以下を適当なディレクトリに保存する．
  2. ukamacs.el:L8 *ukmc-ghost-path* に，ゴーストのディレクトリを設定する．
  3. ukamacs.el:L26 *ukmc-talk-scope-list* にキャラクター名を設定する[^1]．
  4. (load-file "c:/path/to/ukamacs.el") を評価する．

# 主な機能

  | キーバインド          | 機能                              |
  | ---                   | ---                               |
  | M-x ukmc              | 起動                              |
  | M-x ukmc-close        | 終了                              |
  | C-cud                 | ~~おっぱいタッチ~~ ダブルクリック |
  | C-cuw                 | ~~スカートめくり~~ マウスホイール |
  | M-x ukmc-show         | ウィンドウを開く                  |
  | M-x ukmc-close-window | ウィンドウを閉じる                |
  | Ret                   | 選択肢を選択する                  |

  [^1]: キャラクター名の設定を自動化したいのですが，明示的に定義している仕組みがナイ気がする,,,

# 検証環境

  - CentOS Linux release 7.4.1708
  - wine-2.22
  - GNU Emacs 26.3 (build 1, x86_64-w64-mingw32) of 2019-08-29

# 背景

  仕事してるフリしておっぱいさわったりスカートめくったりしたかった．

# 注意事項

## 技術的なこと

   - **セーブデータなどに不整合が生じるおそれがありますので，必ず実験用の環境で評価してください．**
   - *ukmcProcBuf* バッファにログがひたすら溜まり続けます．

## 文化的(?)なこと

  - ゴースト作者さんの意図を大きく損うおそれがあります．お呼び出しする際はよく知っているゴーストさんなどに限定した方が良いと思います．
    - 当たり判定が見えちゃう
    - 表情・アニメーションによるニュアンスが伝わらない (どんな顏して「はーい」と言っているのか,とか)

  逆に，はじめからCUIを前提としたゴースト制作はアリかも.

# 謝辞

  - shioricaller-mti.exeは@Narazakaさんの[shioricaller](https://github.com/Narazaka/shioricaller)をベースに作成しました．shioricallerがなければ、Ukamacsを制作しようと思いませんでした。

    変更内容は複数回の連続したやりとりができるようにした点です．
    ("-mti"は，multiple time interactionのつもりです．)
    変更の影響でオリジナルが備えている入力サンプルに対する出力結果が異なってしまったので
    今回は別の実行ファイル扱いにしましたがホントは合わせ込みたいです
    (力量が足りませんでした．．．)．

  - 非同期制御に[emacs-deferred](https://github.com/kiwanami/emacs-deferred)を使用しています．

# License
"ukamacs" is under [MIT license](https://en.wikipedia.org/wiki/MIT_License).

***
181号, kam
