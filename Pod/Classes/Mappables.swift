//
//  Mappables.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-28.
//
//

import Foundation
import CoreLocation

extension CLRegion : Mappable {
    static func instance(JSON: [String: AnyObject], included: [String: Any]?) -> CLRegion? {
        guard let type = JSON["type"] as? String,
            identifier = JSON["id"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject] else { return nil }
        
        switch type {
        case "ibeacon-regions":
            guard let uuidString = attributes["uuid"] as? String, uuid = NSUUID(UUIDString: uuidString) else { return nil }
            
            let major = attributes["major-number"] as? Int
            let minor = attributes["minor-number"] as? Int
            
            if major != nil && minor != nil {
                return CLBeaconRegion(proximityUUID: uuid, major: CLBeaconMajorValue(major!), minor: CLBeaconMinorValue(minor!), identifier: identifier)
            } else if major != nil {
                return CLBeaconRegion(proximityUUID: uuid, major: CLBeaconMajorValue(major!), identifier: identifier)
            } else {
                return CLBeaconRegion(proximityUUID: uuid, identifier: identifier)
            }
        case "geofence-regions":
            guard let latitude = attributes["latitude"] as? CLLocationDegrees, longitude = attributes["longitude"] as? CLLocationDegrees, radius = attributes["radius"] as? CLLocationDistance else { return nil }
            return CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier)
        default:
            // invalid type
            return nil
        }
        
    }
}

extension Event : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String: Any]?) -> Event? {
        guard let type = JSON["type"] as? String,
            attributes = JSON["attributes"],
            object = attributes["object"] as? String,
            action = attributes["action"] as? String,
            date = included?["date"] as? NSDate
            where type == "events" else { return nil }
        
        switch (object, action) {
        case ("location", "update"):
            guard let
                location = included?["location"] as? CLLocation else { return nil }
            
            return Event.DidUpdateLocation(location, date: date)
        case ("beacon-region", let action):
            guard let
                config = attributes["configuration"] as? [String: AnyObject],
                beaconConfig = BeaconConfiguration.instance(config, included: nil),
                beaconRegion = included?["region"] as? CLBeaconRegion else { return nil }
            
            switch action {
            case "enter":
                return Event.DidEnterBeaconRegion(beaconRegion, config: beaconConfig, date: date)
            case "exit":
                return Event.DidExitBeaconRegion(beaconRegion, config: beaconConfig, date: date)
            default:
                return nil
            }
        case ("geofence-region", let action):
            guard let
                locationJSON = attributes["location"] as? [String: AnyObject],
                location = Location.instance(locationJSON, included: nil),
                circularRegion = included?["region"] as? CLCircularRegion else { return nil }
            
            switch action {
            case "enter":
                return Event.DidEnterCircularRegion(circularRegion, location: location, date: date)
            case "exit":
                return Event.DidExitCircularRegion(circularRegion, location: location, date: date)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

extension BeaconConfiguration : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String: Any]?) -> BeaconConfiguration? {
        guard let
            uuidString = JSON["uuid"] as? String,
            uuid = NSUUID(UUIDString: uuidString),
            name = JSON["name"] as? String,
            tags = JSON["tags"] as? [String] else { return nil }
        
        var majorNumber: CLBeaconMajorValue?
        if let major = JSON["major-number"] as? Int { majorNumber = CLBeaconMajorValue(major) }
        
        var minorNumber: CLBeaconMinorValue?
        if let minor = JSON["minor-number"] as? Int { minorNumber = CLBeaconMinorValue(minor) }
        
        return BeaconConfiguration(name: name, UUID: uuid, majorNumber: majorNumber, minorNumber: minorNumber, tags: tags)
    }
}

extension Location : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Location? {
        guard let
            latitude = JSON["latitude"] as? CLLocationDegrees,
            longitude = JSON["longitude"] as? CLLocationDegrees,
            radius = JSON["radius"] as? CLLocationDistance,
            name = JSON["name"] as? String,
            tags = JSON["tags"] as? [String] else { return nil }
        
        return Location(coordinates: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, name: name, tags: tags)
    }
}
