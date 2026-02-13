import Foundation

extension KPEntry: Hashable {
    static func == (lhs: KPEntry, rhs: KPEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension KPGroup: Hashable {
    static func == (lhs: KPGroup, rhs: KPGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
