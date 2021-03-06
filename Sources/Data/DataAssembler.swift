//
//  DataAssembler.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct DataAssembler: Assembler {
    public var accountToken: String
    public var endpoint: URL
    
    public var flushEventsAt: Int
    public var flushEventsInterval: Double
    public var maxEventBatchSize: Int
    public var maxEventQueueSize: Int
    
    public init(accountToken: String, endpoint: URL = URL(string: "https://api.rover.io/graphql")!, flushEventsAt: Int = 20, flushEventsInterval: Double = 30.0, maxEventBatchSize: Int = 100, maxEventQueueSize: Int = 1000) {
        
        self.accountToken = accountToken
        self.endpoint = endpoint
        
        self.flushEventsAt = flushEventsAt
        self.flushEventsInterval = flushEventsInterval
        self.maxEventBatchSize = maxEventBatchSize
        self.maxEventQueueSize = maxEventQueueSize
    }
    
    public func assemble(container: Container) {
        
        // MARK: ContextManager
        
        container.register(ContextManager.self) { resolver in
            return ContextManager()
        }
        
        // MARK: ContextProvider
        
        container.register(ContextProvider.self) { resolver in
            return ModularContextProvider(
                bluetoothContextProvider: resolver.resolve(BluetoothContextProvider.self),
                debugContextProvider: resolver.resolve(DebugContextProvider.self),
                locationContextProvider: resolver.resolve(LocationContextProvider.self),
                localeContextProvider: resolver.resolve(LocaleContextProvider.self),
                notificationsContextProvider: resolver.resolve(NotificationsContextProvider.self),
                pushTokenContextProvider: resolver.resolve(PushTokenContextProvider.self),
                reachabilityContextProvider: resolver.resolve(ReachabilityContextProvider.self),
                staticContextProvider: resolver.resolve(StaticContextProvider.self)!,
                telephonyContextProvider: resolver.resolve(TelephonyContextProvider.self),
                timeZoneContextProvider: resolver.resolve(TimeZoneContextProvider.self),
                userInfoContextProvider: resolver.resolve(UserInfoContextProvider.self)
            )
        }
        
        // MARK: EventsClient
        
        container.register(EventsClient.self) { resolver in
            return resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: EventQueue
        
        container.register(EventQueue.self) { [flushEventsAt, flushEventsInterval, maxEventBatchSize, maxEventQueueSize] resolver in
            return EventQueue(
                client: resolver.resolve(EventsClient.self)!,
                flushAt: flushEventsAt,
                flushInterval: flushEventsInterval,
                maxBatchSize: maxEventBatchSize,
                maxQueueSize: maxEventQueueSize
            )
        }
        
        // MARK: HTTPClient
        
        container.register(HTTPClient.self) { [accountToken, endpoint] _ in
            return HTTPClient(
                accountToken: accountToken,
                endpoint: endpoint,
                session: URLSession(configuration: URLSessionConfiguration.default)
            )
        }
        
        // MARK: LocaleContextProvider
        
        container.register(LocaleContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: PushTokenContextProvider
        
        container.register(PushTokenContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: ReachabilityContextProvider
        
        container.register(ReachabilityContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: StaticContextProvider
        
        container.register(StaticContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: SyncClient
        
        container.register(SyncClient.self) {  resolver in
            return resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: SyncCoordinator
        
        container.register(SyncCoordinator.self) { resolver in
            let client = resolver.resolve(SyncClient.self)!
            return SyncCoordinatorService(client: client)
        }
        
        // MARK: TimeZoneContextProvider
        
        container.register(TimeZoneContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: TokenManager
        
        container.register(TokenManager.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: URLSession
        
        container.register(URLSession.self) { _ in
            return URLSession(configuration: URLSessionConfiguration.default)
        }
        
        // MARK: UserInfoManager
        
        container.register(UserInfoManager.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
        
        // MARK: UserInfoContextProvider
        
        container.register(UserInfoContextProvider.self) { resolver in
            return resolver.resolve(ContextManager.self)!
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let eventQueue = resolver.resolve(EventQueue.self)!
        eventQueue.restore()
        
        // Set the eventQueue on the LocationManager after assembly to avoid circular dependency
        eventQueue.contextProvider = resolver.resolve(ContextProvider.self)!
    }
}
