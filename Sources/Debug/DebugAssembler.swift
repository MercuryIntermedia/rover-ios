//
//  DebugAssembler.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct DebugAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        
        // MARK: Action (settings)
        
        container.register(Action.self, name: "settings", scope: .transient) { resolver in
            return PresentViewAction(
                viewControllerToPresent: resolver.resolve(UIViewController.self, name: "settings")!,
                animated: true
            )
        }
        
        // MARK: DebugContextProvider
        
        container.register(DebugContextProvider.self) { resolver in
            return DebugContextManager()
        }
        
        // MARK: RouteHandler (settings)
        
        container.register(RouteHandler.self, name: "settings") { resolver in
            return SettingsRouteHandler(
                actionProvider: {
                    return resolver.resolve(Action.self, name: "settings")!
                }
            )
        }
        
        // MARK: UIViewController (settings)
        
        container.register(UIViewController.self, name: "settings", scope: .transient) { resolver in
            return SettingsViewController()
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        let handler = resolver.resolve(RouteHandler.self, name: "settings")!
        resolver.resolve(Router.self)!.addHandler(handler)
    }
}
