import Foundation

extension BattlifyConfig {
    /// A three-way merge of whole configs: the fields `local` changed relative to `base`,
    /// over everything else as `remote` has it now.
    ///
    /// The app writes the whole config on every edit, built from what it last read. Anything
    /// that changed on the daemon's side since then went back over the wire stale: an agent's
    /// lid hold switched off by an unrelated toggle, Always Active switched back on after its
    /// timer had run out. Field by field, whoever actually changed a value wins.
    ///
    /// Merged on the encoded keys so a field added to the config is covered without anyone
    /// remembering to list it here. A key missing from an encoding is an optional that's nil,
    /// and "changed to nil" is a change like any other.
    public static func merge(base: BattlifyConfig, local: BattlifyConfig,
                             remote: BattlifyConfig) -> BattlifyConfig {
        guard local != base else { return remote }
        guard let b = fields(base), let l = fields(local), var merged = fields(remote) else {
            return local
        }
        for key in Set(b.keys).union(l.keys) where !same(l[key], b[key]) {
            merged[key] = l[key]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: merged),
              let config = try? JSONDecoder().decode(BattlifyConfig.self, from: data) else {
            return local
        }
        return config
    }

    private static func fields(_ config: BattlifyConfig) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(config) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func same(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?): return (a as AnyObject).isEqual(b)
        default: return false
        }
    }
}
