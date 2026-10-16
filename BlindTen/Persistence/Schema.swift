import Foundation
import SwiftData

/// Version 1 of the on-device store: the models as shipped in Blind Ten 1.0.
///
/// When a model changes, freeze the old definitions inside this enum (as
/// nested types), add `BlindTenSchemaV2` with the new ones and a migration
/// stage in `BlindTenMigrationPlan`, so players keep their groups and stats.
enum BlindTenSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [StoredPlayer.self, PlayerGroup.self, GameRecord.self, TurnRecord.self, HouseRule.self]
    }
}

enum BlindTenMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BlindTenSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
