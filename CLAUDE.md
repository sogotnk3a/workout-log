# WorkoutLog

筋トレ記録アプリ。SwiftUI + TCA（swift-composable-architecture 1.26）、iOS 26.1 以上、UI は日本語。

- 機能ごとの仕様と、その判断の理由: `docs/specs/`（その機能を触る前に読む）
- 今の状況と次にやること: `docs/ROADMAP.md`

## ビルドと確認

```bash
xcodebuild build -project WorkoutLog.xcodeproj -scheme WorkoutLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation
```

```bash
xcodebuild test -project WorkoutLog.xcodeproj -scheme WorkoutLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipMacroValidation
```

- `-skipMacroValidation` がないと TCA のマクロで失敗する
- テストは `WorkoutLogTests/`（Swift Testing + `TestStore`）。Reducer を変えたらテストも更新する
- テストの関数名は日本語で、何を満たすかを書く（例: `func 保存して終了すると回数を入力したセットだけが終了日時付きで履歴の先頭に入る()`）。説明はコメントではなく関数名で表す
- `@Shared` は参照なので、`.send(.delegate(...))` を受けた親が書き換えた値は、最初の `store.send` の時点で検証する
- Xcode の Issue Navigator に、新しく追加したファイルが「見つからない」という古いエラーが残ることがある。Xcode でビルドし直せば消える（Xcode MCP の `BuildProject` でも可）
- UI を変えたら、シミュレータで操作して確認し、スクショを PR に貼る（`gh pr create/edit --attach ./file.png`）

## プロジェクト構成

- `WorkoutLog/` はフォルダ同期グループ。ファイルを置くだけでビルド対象になり、`project.pbxproj` の編集は不要
- `App/`: ルートの `AppFeature`（タブと記録画面の表示）、`Features/<機能名>/`: 機能ごとの Feature と View、`Models/`: モデルと `@Shared` のキー
- Feature と View は同じファイルに置く

## TCA の書き方

- 子から親への通知は `delegate` アクションにする（例: `.delegate(.finished)`）
- 画面遷移: モーダルは `@Presents var destination` と `@Reducer enum Destination`、push は `StackState`
- 永続化は `@Shared(.fileStorage(...))`。キーは `Models/` に `SharedKey` の拡張として定義する
- 親の `@Shared` の一部を子に渡すときは `Shared($workout.exercises[id: id])` のように切り出す
- 依存（時刻・UUID・時計・dismiss）は `@Dependency` 経由にする

## 落とし穴（iOS 26）

- 確認には `confirmationDialog` ではなく `alert` を使う。iOS 26 ではポップオーバーで表示され、外側をタップして閉じても TCA に伝わらず、次から開かなくなる
- `onDelete` の削除ボタンは英語（Delete）になる。`swipeActions` に「削除」ボタンを自分で付ける
- List の行の中に複数のボタンを置くときは `.buttonStyle(.borderless)` にする（行全体のタップに吸われるため）
- 記録ボタンは `Tab(role: .search)` で、タブバーの右に独立して表示される。選ばれてもタブは切り替えず、`TabView` の selection の Binding で受け取ってモーダルを開く

## 作業のルール

- 設計や見た目に関わることは、合意してから実装する。UI のたたき台は Design キャンバスで出す
- 作業はブランチを切って PR にする。main に直接コミットしない
- コミットと PR に Claude の署名を付けない
