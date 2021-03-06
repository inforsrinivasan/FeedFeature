//
//  LocalFeedLoader.swift
//  FeedFeature
//
//  Created by Srinivasan Rajendran on 2020-12-22.
//

import Foundation

public class LocalFeedLoader {
    private let store: FeedStore
    private let currentDate: () -> Date

    public init(store: FeedStore, currentDate: @escaping () -> Date) {
        self.store = store
        self.currentDate = currentDate
    }
}

extension LocalFeedLoader {

    public typealias SaveResult = Result<Void, Error>

    public func save(items: [FeedItem], completion: @escaping (SaveResult) -> Void) {
        store.deleteCachedFeed { [weak self] deletionResult in
            guard let self = self else { return }
            switch deletionResult {
            case .success:
                self.cache(items: items, completion: completion)
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func cache(items: [FeedItem], completion: @escaping (SaveResult) -> Void) {
        store.insertFeed(items: items.toLocal(), timestamp: self.currentDate()) { [weak self] error in
            guard self != nil  else { return }
            completion(error)
        }
    }
}

extension LocalFeedLoader: FeedLoader {

    public typealias LoadResult = FeedLoader.Result

    public func load(completion: @escaping (LoadResult) -> Void) {
        store.retrieveFeed { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case let .success(.some(cache)) where FeedCachePolicy.validate(cache.timestamp, against: self.currentDate()) :
                completion(.success(cache.feed.toModel()))
            case .success:
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
            case let .success(.some(cache)) where !FeedCachePolicy.validate(cache.timestamp, against: self.currentDate()) :
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
