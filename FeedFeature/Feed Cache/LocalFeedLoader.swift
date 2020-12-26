//
//  LocalFeedLoader.swift
//  FeedFeature
//
//  Created by Srinivasan Rajendran on 2020-12-22.
//

import Foundation

private final class FeedCachePolicy {

    private let calendar = Calendar(identifier: .gregorian)

    private var maxCacheAgeInDays: Int {
        return 7
    }

    func validate(_ timestamp: Date, against date: Date) -> Bool {
        guard let maxCachAge = calendar.date(byAdding: .day, value: maxCacheAgeInDays, to: timestamp) else {
            return false
        }
        return date < maxCachAge
    }

}

public class LocalFeedLoader {
    private let store: FeedStore
    private let currentDate: () -> Date
    private let cachePolicy = FeedCachePolicy()

    public init(store: FeedStore, currentDate: @escaping () -> Date) {
        self.store = store
        self.currentDate = currentDate
    }

    private func cache(items: [FeedItem], completion: @escaping (SaveResult) -> Void) {
        store.insertFeed(items: items.toLocal(), timestamp: self.currentDate()) { [weak self] error in
            guard self != nil  else { return }
            completion(error)
        }
    }
}

extension LocalFeedLoader {

    public typealias SaveResult = Error?

    public func save(items: [FeedItem], completion: @escaping (SaveResult) -> Void) {
        store.deleteCachedFeed { [weak self] error in
            guard let self = self else { return }
            if let cacheDeletionError = error {
                completion(cacheDeletionError)
            } else {
                self.cache(items: items, completion: completion)
            }
        }
    }
}

extension LocalFeedLoader: FeedLoader {

    public typealias LoadResult = FeedResult

    public func load(completion: @escaping (LoadResult) -> Void) {
        store.retrieveFeed { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case let .found(items, timestamp) where self.cachePolicy.validate(timestamp, against: self.currentDate()) :
                completion(.success(items.toModel()))
            case .found, .empty:
                completion(.success([]))
            }
        }
    }
}

extension LocalFeedLoader {
    public func validateCache() {
        store.retrieveFeed { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure:
                self.store.deleteCachedFeed { _ in }
            case let .found(_, timestamp) where !self.cachePolicy.validate(timestamp, against: self.currentDate()) :
                self.store.deleteCachedFeed { _ in }
            default:
                break
            }
        }
    }
}

private extension Array where Element == FeedItem {
    func toLocal() -> [LocalFeedItem] {
        return map { LocalFeedItem(id: $0.id, description: $0.description, location: $0.location, imageURL: $0.imageURL) }
    }
}

private extension Array where Element == LocalFeedItem {
    func toModel() -> [FeedItem] {
        return map { FeedItem(id: $0.id, description: $0.description, location: $0.location, imageURL: $0.imageURL) }
    }
}
