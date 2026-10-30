//
//  UserProfile.swift
//  WorkoutLog
//

import ComposableArchitecture
import Foundation

/// マイページで設定する自分のプロフィール。サーバーができるまでは端末内だけに保存する
struct UserProfile: Equatable, Codable, Sendable {
    var photoData: Data?
    var message: String?
}

extension SharedKey where Self == FileStorageKey<UserProfile>.Default {
    static var userProfile: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "user-profile.json")), default: UserProfile()]
    }
}

extension UserProfile {
    /// ひとことメッセージのテンプレート。自由入力にはせず、ここから選ぶ
    static let messageTemplates = [
        "今日も追い込み中",
        "誰にも負けない",
        "筋肉は裏切らない",
        "黙って筋トレ",
        "限界突破中",
        "サボってるやつ見てるか",
    ]
}
