
import Foundation

final class CacheManager {
    static let shared = CacheManager()

    private let cache = NSCache<NSString, AnyObject>()
    private let userDefaults = UserDefaults.standard

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func cache<T: AnyObject>(_ object: T, forKey key: String, expiryDate: Date? = nil) {
        let cacheKey = NSString(string: key)
        cache.setObject(object, forKey: cacheKey)

        if let expiryDate = expiryDate {
            userDefaults.set(expiryDate, forKey: "\(key)_expiry")
        }
    }

    func get<T>(forKey key: String, as type: T.Type) -> T? {
        let cacheKey = NSString(string: key)

        if let expiryDate = userDefaults.object(forKey: "\(key)_expiry") as? Date,
           expiryDate < Date() {
            remove(forKey: key)
            return nil
        }

        return cache.object(forKey: cacheKey) as? T
    }

    func remove(forKey key: String) {
        let cacheKey = NSString(string: key)
        cache.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: "\(key)_expiry")
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    func setLastSyncDate(_ date: Date, forBank bankId: String) {
        let key = "\(Constants.UserDefaultsKeys.lastSyncDate)_\(bankId)"
        userDefaults.set(date, forKey: key)
    }

    func getLastSyncDate(forBank bankId: String) -> Date? {
        let key = "\(Constants.UserDefaultsKeys.lastSyncDate)_\(bankId)"
        return userDefaults.object(forKey: key) as? Date
    }

    func needsSync(forBank bankId: String) -> Bool {
        guard let lastSync = getLastSyncDate(forBank: bankId) else {
            return true
        }
        return Date().timeIntervalSince(lastSync) > Constants.Sync.cacheValidityDuration
    }
}
