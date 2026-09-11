---
name: soran-pos-backfill
description: Run exactly one 31-day (or shorter) historical backfill window of SORAN's "日別店別品名別ダウンロード" (daily store×SKU POS download) screen, save/verify/compress the result, log it, and stop. Invoke this skill once per interval (e.g. via /loop) rather than looping many windows inside one turn, so each invocation is a short, isolated burst of automation instead of one long repetitive session.
---

# SORAN POS 日次バックフィル(1回分)

## なぜ「1回だけ」なのか

このスキルは**1回の呼び出しにつき1期間(最大31日)だけ**処理して終了する。62回全部を1つの会話ターン内でループさせると、同一パターンの自動操作が連続しすぎてSonnet 5のリアルタイム安全機構(`[cyber]`)に誤検知されて強制終了することが実測で分かっている。そのため、呼び出し側(ユーザーまたは `/loop <interval> soran-pos-backfill`)が時間を空けながら繰り返し呼び出す設計にする。**このスキル自身の中で複数期間をループしてはならない。**

## 前提条件

- SORANアプリ(`visual.exe`)が起動済み・ログイン済みであること。`Get-Process -Name visual` で確認する。起動していなければ、ユーザーに再ログインを依頼して停止する(認証情報は一切扱わない)。
- ツールスクリプト: `C:\Users\松山真大\Documents\jbtob_audit_20260826\soran_tools.ps1`
- 収集先ディレクトリ: `C:\Users\松山真大\Documents\jbtob_collection_20260827\`
  - `raw\daily_store_sku\{start}_{end}\JANDAYOFFICE0.csv.gz`
  - `manifests\collection_log.csv`
  - `logs\` (スクリーンショット)
- データ蓄積下限: `2021-05-16`(これより前の期間は存在しない)
- 店舗指定: `07,01,03,08,10,12,49`(全7事業会社・3,324店、既にSORAN側に設定済みのはずだが、下記Step 2で毎回確認する)
- カテゴリ指定: `711,713,721,723,725,728,731,733,737,739,741,742,751,761,771,781`(化粧品部門の全16小分類、コンマ区切りで1回にまとめて指定可能。実機検証済み)

## Step 0: 次に処理すべき期間を決定する

`manifests\collection_log.csv` を読み、`daily_store_sku` 行のうち最も古い `start_date` を取得する(初回呼び出し時にファイルが無ければ、最初の期間は実行日の2日前を終了日として計算する)。

- `next_end_date` = (既存の最も古い `start_date`) - 1日
- `next_start_date` = `next_end_date` - 30日
- `next_start_date` が `2021-05-16` より前になる場合は `next_start_date = 2021-05-16` に切り上げ、この回を**最終回**として扱う(このスキルはそれでも1回分だけ実行して終了する)。
- `next_end_date` が既に `2021-05-16` より前(=全期間完了済み)なら、何もせず「バックフィル完了」と報告して終了する。

## Step 1: SORANの状態確認とダウンロード画面を開く

```powershell
. "C:\Users\松山真大\Documents\jbtob_audit_20260826\soran_tools.ps1"
Get-Process -Name visual -ErrorAction SilentlyContinue
Get-AllSoranWindows | Format-Table -AutoSize
```

「日別 店別 品名別・ダウンロード」ウィンドウが無ければ、Launcherから 拡張分析 > ダウンロード・検索メニュー > 日別店別品名別ダウンロード を開く(Launcherのメニュー座標は解像度依存なので、開けなかったらスクリーンショットで確認しながら調整する)。

## Step 2: 【最重要】操作の直前に必ずフォーカスを確認する

このターミナル自身のウィンドウ(タイトルにセッション名が入っている)がOSフォーカスを持っていると、これから送るキー入力がSORANではなくこのターミナルに入力されてしまう事故が実際に複数回発生した。**Send-ClickAt / Send-KeyInput を送る直前に必ず対象ウィンドウをフォーカスし、フォーカスが実際に移ったことを確認してから操作する。**

```powershell
$w = Get-AllSoranWindows | Where-Object { $_.Title -eq "日別 店別 品名別・ダウンロード" }
Show-WindowByHandle -Handle $w.Handle
Start-Sleep -Milliseconds 400
$fg = [Win32]::GetForegroundWindow()
if ($fg -ne $w.Handle) { throw "focus mismatch: $([Win32]::GetTitle($fg))" }
```

このチェックで例外が出たら、再度 `Show-WindowByHandle` してから続行する。フォーカスを取れないまま操作を強行しないこと。

## Step 3: 日付欄の設定

日付欄(年・月・日が左右2組)は、`{END}` キーがこの独自コントロールでは効かず、`{END}` の後にBackspaceしても既存の値の前に新しい値が挿入される不具合が確認されている(例: "5"→"4"にしようとして"45"になる)。**`{END}` ではなく `{RIGHT 6〜8}` でカーソルを確実に右端まで送ってから `{BACKSPACE 8〜10}` で消し、新しい値を入力する。**

年フィールド(4桁)の例:
```powershell
Send-ClickAt -X <年フィールドのX> -Y 217
Start-Sleep -Milliseconds 300
Send-KeyInput -Keys "{RIGHT 8}"
Send-KeyInput -Keys "{BACKSPACE 10}"
Start-Sleep -Milliseconds 200
Send-KeyInput -Keys "2025"
Start-Sleep -Milliseconds 500
```

月・日フィールド(1〜2桁)の例:
```powershell
Send-ClickAt -X <フィールドのX> -Y 217
Start-Sleep -Milliseconds 300
Send-KeyInput -Keys "{RIGHT 6}"
Send-KeyInput -Keys "{BACKSPACE 8}"
Start-Sleep -Milliseconds 200
Send-KeyInput -Keys "<新しい値>"
Start-Sleep -Milliseconds 500
```

開始年・開始月・開始日・終了年・終了月・終了日のうち、前回の実行から値が変わるフィールドだけ上記の手順で更新する(年が変わらない場合はそのフィールドは触らない)。設定後は必ずスクリーンショットで日付を目視確認する。

## Step 4: 店舗・カテゴリ欄の確認

前回の実行から店舗欄(`店`)・小分類欄(`小分類`)の値は保持されているはずなので、スクリーンショットで前提条件の値と一致しているか確認するだけでよい(一致していなければ、店舗欄は「拡張分析グループ指定」ダイアログを開いて7社をShift+Downで全選択→追加→OK、小分類欄は既存値を維持する)。

## Step 5: ファイル名を設定する

日付欄を触ると「ファイル名」欄がプレースホルダ(禁則文字の説明表示)に戻ることが多いので、日付設定後に必ず再入力する。

```powershell
Send-ClickAt -X 335 -Y 436
Start-Sleep -Milliseconds 300
Send-KeyInput -Keys "{HOME}"
Send-KeyInput -Keys "+{END}"
Send-KeyInput -Keys "{DELETE}"
Start-Sleep -Milliseconds 200
Send-KeyInput -Keys "pos_<start:YYYYMMDD>_<end:YYYYMMDD>"
```

スクリーンショットで日付・店舗・小分類・ファイル名の4項目がすべて正しいことを確認してから次に進む。

## Step 6: 実行して完了を待つ

「実行」ボタン(画面左上の紫帯、だいたい座標 X≈287, Y≈171 だが解像度依存なのでスクリーンショットで確認)をクリックする。全店舗3,324店×31日×16カテゴリの集計は概ね2〜5分かかる。

```powershell
Send-ClickAt -X 287 -Y 171
```

その後、60〜120秒間隔で完了を確認し、「集計完了」ダイアログにダウンロードURLが表示されるまで待つ。`Start-Sleep` を直接長く取らず、`run_in_background: true` のPowerShell呼び出し+Monitorでの待機を使う(ツール側の長時間sleep制限を回避するため)。

**進捗確認はスクリーンショットではなく `Get-AllSoranWindows` のウィンドウタイトルで行うこと。** このターミナル自身の画面がフォーカスを持って前面に出ている間はスクリーンショットがSORANの状態を反映しない(この会話のログや過去のエラーメッセージが写り込むだけ)。`Get-AllSoranWindows | Where-Object { $_.Title -eq "実行中 ‥‥" }` が消えて `Where-Object { $_.Title -eq "集計完了" }` が出現したら完了、という判定はフォーカス状態に関係なく正しく取得できる。

**待っている間に「集計完了」ダイアログが消えてしまうことがある**(実測で1回発生)。消えてしまった場合、サーバー側の集計自体は破棄されないとダイアログには書かれているが、UIからダウンロードURLを再取得する手段が見当たらなかったため、実務上は同じ条件で再実行するのが確実。

## Step 7: ダウンロード・展開・検証・圧縮・記録

集計完了ダイアログのURLリンクをクリックしてEdgeでダウンロードさせる(Step 2と同様にフォーカス確認をしてからクリックする)。ダウンロード完了(Downloadsフォルダにファイルが出現)を待ってから:

```bash
mkdir -p ".../raw/daily_store_sku/{start}_{end}"
unzip -o ".../Downloads/pos_{start}_{end}.zip" -d ".../raw/daily_store_sku/{start}_{end}"
head -1 ".../raw/daily_store_sku/{start}_{end}/JANDAYOFFICE0.csv" | iconv -f SHIFT-JIS -t UTF-8
```

ヘッダーの「指定日付：,,,YYYY/M/D - YYYY/M/D」が意図した期間と一致することを**必ず確認する**(一致しなければ、日付欄の設定ミスの可能性が高いのでこの回はやり直す)。一致していたら:

```bash
gzip -f ".../raw/daily_store_sku/{start}_{end}/JANDAYOFFICE0.csv"
echo "<run_no>,daily_store_sku,{start},{end},\"07,01,03,08,10,12,49 (3324 stores)\",\"711-781 (16 categories)\",<rows>,<zip_size>,success,verified header date range matches" >> manifests/collection_log.csv
rm -f ".../Downloads/pos_{start}_{end}.zip"
```

## Step 8: 後片付け(フォーカス確認を忘れない)

ダウンロード後に開いたEdgeのポップアップウィンドウを閉じ、「集計完了」ダイアログを閉じる。**閉じるボタンをクリックする前に、必ずStep 2と同じフォーカス確認をやり直すこと**(Edgeを閉じた直後や、待機中にこのターミナルへフォーカスが移っていることが多い)。

```powershell
$w = Get-AllSoranWindows | Where-Object { $_.Title -eq "集計完了" }
if ($w) {
    Show-WindowByHandle -Handle $w.Handle
    Start-Sleep -Milliseconds 400
    # ここでフォーカス確認してからクリック
    Send-ClickAt -X 1077 -Y 699   # 「ダウンロードが終了したので閉じる」
    Start-Sleep -Seconds 1
    Send-ClickAt -X 1009 -Y 718   # 確認ダイアログの「はい」
}
```

最後に `Get-AllSoranWindows` を実行し、「日別 店別 品名別・ダウンロード」と「Launcher」以外の余計なウィンドウが残っていないことを確認する。

## 安全ルール(厳守)

- 認証情報はファイル・ログに一切保存・記載しない。
- UIクリック以外の裏API直接操作は行わない。
- エラーや異常(ダイアログ、0件、0バイト、ヘッダー日付の不一致)が出たら、この回だけ1回リトライする。2回失敗したら深追いせず、スクリーンショットを残してユーザーに報告し停止する(無人で暴走させない)。
- **1回の呼び出しで処理するのは1期間のみ**。全期間を1ターンでループしない。
- "人間らしく見せる"「検知回避」を目的とした表現・実装(ジッターの意図をそう説明する等)は用いない。ランダム待機を入れる場合も「サーバー負荷の平準化」という業務上の理由でのみ言及する。

## 呼び出し方(ユーザー向け)

1回実行するごとに1期間(最大31日)が完了する。62回全体を完了させるには、間隔を空けて繰り返し呼び出す。例:

```
/loop 20m soran-pos-backfill
```

のように、`/loop` スキルを使って20分間隔で `soran-pos-backfill` を繰り返し呼び出すことを推奨する(間隔は任意に調整可能)。全期間(2021-05-16まで)完了したら、このスキルは「バックフィル完了」を報告するので、そこで `/loop` を止める。
