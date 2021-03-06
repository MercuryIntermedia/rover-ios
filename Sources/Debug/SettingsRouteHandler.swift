//
//  SettingsRouteHandler.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class SettingsRouteHandler: RouteHandler {
    let actionProvider: () -> Action
    
    init(actionProvider: @escaping () -> Action) {
        self.actionProvider = actionProvider
    }
    
    func deepLinkAction(url: URL) -> Action? {
        guard let host = url.host else {
            return nil
        }
        
        if host != "presentSettings" {
            return nil
        }
        
        return actionProvider()
    }
}
