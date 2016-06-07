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
            guard let latitude = attributes["latitude"] as? CLLocationDegrees,
                longitude = attributes["longitude"] as? CLLocationDegrees,
                radius = attributes["radius"] as? CLLocationDistance else { return nil }
            
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
            attributes = JSON["attributes"] as? [String: AnyObject],
            object = attributes["object"] as? String,
            action = attributes["action"] as? String,
            date = included?["date"] as? NSDate
            where type == "events" else { return nil }
        
        switch (object, action) {
        case ("app", "open"):
            return nil
        case ("location", "update"):
            guard let
                location = included?["location"] as? CLLocation else { return nil }
            
            return Event.DidUpdateLocation(location, date: date)
        case ("beacon-region", let action):
            guard let
                config = attributes["configuration"] as? [String: AnyObject],
                beaconConfig = BeaconConfiguration.instance(config, included: nil),
                beaconRegion = included?["region"] as? CLBeaconRegion else { return nil }
            
            var place: Place?
            if let placeAttributes = attributes["place"] as? [String: AnyObject] {
                place = Place.instance(placeAttributes, included: nil)
            }
            
            switch action {
            case "enter":
                return Event.DidEnterBeaconRegion(beaconRegion, config: beaconConfig, place: place, date: date)
            case "exit":
                return Event.DidExitBeaconRegion(beaconRegion, config: beaconConfig, place: place, date: date)
            default:
                return nil
            }
        case ("geofence-region", let action):
            guard let
                placeJSON = attributes["place"] as? [String: AnyObject],
                place = Place.instance(placeJSON, included: nil),
                circularRegion = included?["region"] as? CLCircularRegion else { return nil }
            
            switch action {
            case "enter":
                return Event.DidEnterCircularRegion(circularRegion, place: place, date: date)
            case "exit":
                return Event.DidExitCircularRegion(circularRegion, place: place, date: date)
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

extension Place : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Place? {
        guard let
            latitude = JSON["latitude"] as? CLLocationDegrees,
            longitude = JSON["longitude"] as? CLLocationDegrees,
            radius = JSON["radius"] as? CLLocationDistance,
            name = JSON["name"] as? String,
            tags = JSON["tags"] as? [String] else { return nil }
        
        return Place(coordinates: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, name: name, tags: tags)
    }
}

extension Message : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Message? {
        guard let type = JSON["type"] as? String,
            identifier = JSON["id"] as? String,
            attributes = JSON["attributes"] as? [String: AnyObject],
            title = attributes["ios-title"] as? String?,
            timestampString = attributes["timestamp"] as? String,
            timestamp = rvDateFormatter.dateFromString(timestampString),
            text = attributes["notification-text"] as? String,
            properties = attributes["properties"] as? [String: String]
            where type == "messages" else { return nil }
        
        
        
        let message = Message(title: title, text: text, timestamp: timestamp, identifier: identifier, properties: properties)

        message.read = attributes["read"] as? Bool ?? false
        message.savedToInbox = attributes["saved-to-inbox"] as? Bool ?? false
        
        if let action = attributes["content-type"] as? String {
            switch action {
            case "website":
                message.action = .Link
                // TODO: this can throw, needs to be safer
                if let url = attributes["website-url"] as? String {
                    message.url = NSURL(string: url)
                }
            case "landing-page":
                message.action = .LandingPage
                
                if let landingPageAttributes = attributes["landing-page"] as? [String: AnyObject] {
                    message.landingPage = Screen.instance(landingPageAttributes, included: nil)
                }
            default:
                message.action = .None
            }
        }

        
        return message
    }
}

extension Screen : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Screen? {
        guard let rowsAttributes = JSON["rows"] as? [[String : AnyObject]],
            rows = rowsAttributes.map({ Row.instance($0, included: nil) }) as? [Row] else { return nil }
        
        let screen = Screen(rows: rows)
        screen.title = JSON["title"] as? String
        
        return screen
    }
}

extension Row : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Row? {
        guard let blocksAttributes = JSON["blocks"] as? [[String : AnyObject]],
            blocks = blocksAttributes.map({ Block.instance($0, included: nil) }) as? [Block] else { return nil }
        
        let row = Row(blocks: blocks)
        row.height = Unit.instance(JSON["height"] as? [String: AnyObject] ?? [:], included: nil)
        
        return row
    }
}

extension Block : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Block? {
        guard let type = JSON["type"] as? String else { return nil }
        
        var block: Block
        
        switch type {
        case "image-block":
            let image = Image.instance(JSON["image"] as? [String: AnyObject] ?? [:], included: nil)
            
            block = ImageBock(image: image)
        case "text-block":
            block = TextBlock()
            
            let textBlock = block as! TextBlock
            textBlock.text = JSON["text"] as? String
            textBlock.textAlignment = Alignment.instance(JSON["text-alignment"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.textAlignment
            textBlock.textOffset = Offset.instance(JSON["text-offset"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.textOffset
            textBlock.textColor = UIColor.instance(JSON["text-color"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.textColor
            
            let fontSize = JSON["text-font-size"] as? CGFloat
            let fontWeight = JSON["text-font-weight"] as? CGFloat
            
            textBlock.font = UIFont.instance(JSON["text-font"] as? [String: AnyObject] ?? [:], included: nil) ?? textBlock.font
            
        case "button-block":
            block = ButtonBlock()
            
            let buttonBlock = block as! ButtonBlock
            
            buttonBlock.action = ButtonBlock.Action.instance(JSON["action"] as? [String: AnyObject] ?? [:], included: nil)
            if let states = JSON["states"] as? [String: AnyObject] {
                buttonBlock.appearences[.Normal] = ButtonBlock.Appearance.instance(states["normal"] as? [String: AnyObject] ?? [:], included: nil)
                buttonBlock.appearences[.Highlighted] = ButtonBlock.Appearance.instance(states["highlighted"] as? [String: AnyObject] ?? [:], included: nil)
                buttonBlock.appearences[.Selected] = ButtonBlock.Appearance.instance(states["selected"] as? [String: AnyObject] ?? [:], included: nil)
                buttonBlock.appearences[.Disabled] = ButtonBlock.Appearance.instance(states["disabled"] as? [String: AnyObject] ?? [:], included: nil)
            }
            
        default:
            return nil
        }
        
        // Layout
        
        block.width = Unit.instance(JSON["width"] as? [String: AnyObject] ?? [:], included: nil)
        block.height = Unit.instance(JSON["height"] as? [String: AnyObject] ?? [:], included: nil)
        block.position = Block.Position(rawValue: JSON["position"] as? String ?? "") ?? block.position
        block.alignment = Alignment.instance(JSON["alignment"] as? [String: AnyObject] ?? [:], included: nil) ?? block.alignment
        block.offset = Offset.instance(JSON["offset"] as? [String: AnyObject] ?? [:], included: nil) ?? block.offset
        
        // Appearance

        block.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil) ?? block.backgroundColor
        block.borderColor = UIColor.instance(JSON["border-color"] as? [String: AnyObject] ?? [:], included: nil) ?? block.borderColor
        block.borderRadius = JSON["border-radius"] as? CGFloat ?? block.borderRadius
        block.borderWidth = JSON["border-width"] as? CGFloat ?? block.borderWidth
        
        return block
    }
}

extension ButtonBlock.Action : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> ButtonBlock.Action? {
        guard let type = JSON["type"] as? String,
            urlString = JSON["url"] as? String,
            url = NSURL(string: urlString) else { return nil }
        
        switch type {
        case "website-action":
            return .Website(url)
        case "deep-link-action":
            return .Deeplink(url)
        default:
            return nil
        }
    }
}

extension ButtonBlock.Appearance : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> ButtonBlock.Appearance? {
        var appearance = ButtonBlock.Appearance()
        appearance.title = JSON["text"] as? String
        appearance.titleAlignment = Alignment.instance(JSON["text-alignment"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.titleOffset = Offset.instance(JSON["text-offset"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.titleColor = UIColor.instance(JSON["text-color"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.titleFont = UIFont.instance(JSON["text-font"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.backgroundColor = UIColor.instance(JSON["background-color"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.borderColor = UIColor.instance(JSON["border-color"] as? [String: AnyObject] ?? [:], included: nil)
        appearance.borderRadius = JSON["border-radius"] as? CGFloat
        appearance.borderWidth = JSON["border-width"] as? CGFloat
        return appearance
    }
}

extension Image: Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Image? {
        guard let width = JSON["width"] as? CGFloat,
            height = JSON["height"] as? CGFloat,
            urlString = JSON["url"] as? String,
            url = NSURL(string: urlString) else { return nil }
        
        return Image(size: CGSize(width: width, height: height), url: url)
    }
}

extension Offset : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Offset? {
        let top = Unit.instance(JSON["top"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let right = Unit.instance(JSON["right"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let bottom = Unit.instance(JSON["bottom"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let left = Unit.instance(JSON["left"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let center = Unit.instance(JSON["center"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)
        let middle = Unit.instance(JSON["middle"] as? [String: AnyObject] ?? [:], included: nil) ?? .Points(0)

        return Offset(left: left, right: right, top: top, bottom: bottom, center: center, middle: middle)
    }
}

extension Alignment : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Alignment? {
        let horizontal = Alignment.HorizontalAlignment(rawValue: JSON["horizontal"] as? String ?? "left")
        let vertical = Alignment.VerticalAlignment(rawValue: JSON["vertical"] as? String ?? "top")
        
        return Alignment(horizontal: horizontal!, vertical: vertical!)
    }
}

extension Unit : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> Unit? {
        guard let value = JSON["value"] as? CGFloat,
            type = JSON["type"] as? String else { return nil }
        
        switch type {
        case "points":
            return Unit.Points(value)
        case "percentage":
            return Unit.Percentage(value)
        default:
            return nil
        }
    }
}

extension UIColor : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> UIColor? {
        guard let red = JSON["red"] as? CGFloat,
            blue = JSON["blue"] as? CGFloat,
            green = JSON["green"] as? CGFloat,
            alpha = JSON["alpha"] as? CGFloat else { return nil }
        
        return UIColor(red: red/255.0, green: green/255.0, blue: blue/255.0, alpha: alpha)
    }
}

extension UIFont : Mappable {
    static func instance(JSON: [String : AnyObject], included: [String : Any]?) -> UIFont? {
        guard let fontSize = JSON["size"] as? CGFloat,
            fontWeight = JSON["weight"] as? Int else { return UIFont.systemFontOfSize(12) }
        
        let weights = [
            100: UIFontWeightUltraLight,
            200: UIFontWeightThin,
            300: UIFontWeightLight,
            400: UIFontWeightRegular,
            500: UIFontWeightMedium,
            600: UIFontWeightSemibold,
            700: UIFontWeightBold,
            800: UIFontWeightHeavy,
            900: UIFontWeightBlack
        ]
        
        return UIFont.systemFontOfSize(fontSize, weight: weights[fontWeight] ?? UIFontWeightRegular)
    }
}
