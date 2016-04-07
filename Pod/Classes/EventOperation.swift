//
//  EventOperation.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-15.
//
//
//                                         +--------+
//                                         | Region |
//                                   +--<--|  Map   |--<--+
//                                   |     +--------+     |
//                                   |                    |
// 	+--------+   +-----------+   +------+   +-------+     +--------+
// 	|  BLE   |-<-|   Event   |-<-| HTTP |-<-| Event |--<--| Finish |
// 	| Status |   | Serialize |   |      |   |  Map  |     |        |
// 	+--------+   +-----------+   +------+   +-------+     +--------+
// 	                                 |                    |
// 	                                 |     +---------+    |
// 	                                 |     | Message |    |
//	                                 +--<--|  Map    |-<--+
//	                                       +---------+
//

import UIKit
import CoreLocation

protocol EventOperationDelegate: class {
    func eventOperation(operation: EventOperation, didPostEvent event: Event)
    func eventOperation(operation: EventOperation, didReceiveRegions regions: [CLRegion])
    func eventOperation(operation: EventOperation, didReceiveMessages messages: [Message])
}

class EventOperation: ConcurrentOperation {

    private let bluetoothOperationQueue = NSOperationQueue()
    private let internalQueue = NSOperationQueue()
    
    weak var delegate: EventOperationDelegate?
    
    required init(event: Event) {
        super.init()
        
        bluetoothOperationQueue.maxConcurrentOperationCount = 1
        
        bluetoothOperationQueue.suspended = true
        internalQueue.suspended = true
        
        // Operations
        
        let finishingOperation = NSBlockOperation {
            self.finish()
        }
        let messageMappingOperation = MappingOperation { (messages: [Message]) in
            guard messages.count > 0 else { return }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.eventOperation(self, didReceiveMessages: messages)
            }
        }
        let regionMappingOperation = MappingOperation { (regions: [CLRegion]) in
            guard regions.count > 0 else { return }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.delegate?.eventOperation(self, didReceiveRegions: regions)
            }
        }
        let eventMappingOperation = MappingOperation { (event: Event) in
            // TODO: dispatch_async?
            self.delegate?.eventOperation(self, didPostEvent: event)
        }
        let networkOperation = NetworkOperation(mutableUrlRequest: Router.Events.urlRequest) { JSON, error in
            //
            //
            //
            if let included = JSON?["included"] as? [[String: AnyObject]] {
                regionMappingOperation.json = ["data": included]
                messageMappingOperation.json = ["data": included]
            }
            eventMappingOperation.json = JSON
        }
        let serializingOperation = SerializingOperation(model: event) { JSON in
            networkOperation.payload = JSON
        }
        let bluetoothStatusOperation = BluetoothStatusOperation { isOn in
            Device.bluetoothOn = isOn
        }
        
        eventMappingOperation.included = event.properties
        
        finishingOperation.addDependency(messageMappingOperation)
        finishingOperation.addDependency(eventMappingOperation)
        finishingOperation.addDependency(regionMappingOperation)
        
        messageMappingOperation.addDependency(networkOperation)
        eventMappingOperation.addDependency(networkOperation)
        regionMappingOperation.addDependency(networkOperation)
        networkOperation.addDependency(serializingOperation)
        serializingOperation.addDependency(bluetoothStatusOperation)
        
        bluetoothOperationQueue.addOperation(bluetoothStatusOperation)
        internalQueue.addOperation(serializingOperation)
        internalQueue.addOperation(networkOperation)
        internalQueue.addOperation(eventMappingOperation)
        internalQueue.addOperation(regionMappingOperation)
        internalQueue.addOperation(messageMappingOperation)
        
        internalQueue.addOperation(finishingOperation)
    }
    
    override func cancel() {
        bluetoothOperationQueue.cancelAllOperations()
        internalQueue.cancelAllOperations()
        
        super.cancel()
    }
    
    override func execute() {
        bluetoothOperationQueue.suspended = false
        internalQueue.suspended = false
    }
    
}
