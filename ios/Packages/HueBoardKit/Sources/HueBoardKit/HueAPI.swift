import Foundation

public struct HueAPIErrorPayload:Codable,Equatable,Sendable{public let description:String}
public struct HueAPIResponse<Value:Codable&Sendable>:Codable,Sendable{public let errors:[HueAPIErrorPayload];public let data:[Value]}
public struct HueResourceAcknowledgement:Codable,Equatable,Sendable{public let resourceID:HueResourceID;public let resourceType:String?;enum CodingKeys:String,CodingKey{case resourceID="rid";case resourceType="rtype"}}
public struct HueBridgeConfiguration:Codable,Equatable,Sendable{public let bridgeID:String?;public let modelID:String?;public let apiVersion:String?;enum CodingKeys:String,CodingKey{case bridgeID="bridgeid";case modelID="modelid";case apiVersion="apiversion"}}
public struct HueDiscoveryRecord:Codable,Equatable,Sendable{public let id:String;public let internalIPAddress:String;public let port:Int?;enum CodingKeys:String,CodingKey{case id;case internalIPAddress="internalipaddress";case port};public var candidate:HueBridgeCandidate{.init(id:id,host:internalIPAddress,port:port ?? 443)}}
public struct HuePairingEntry:Codable,Equatable,Sendable{
    public struct Success:Codable,Equatable,Sendable{public let username:String;public let clientKey:String?;enum CodingKeys:String,CodingKey{case username;case clientKey="clientkey"}}
    public struct Failure:Codable,Equatable,Sendable{public let type:Int?;public let address:String?;public let description:String}
    public let success:Success?;public let error:Failure?
}
public struct HueMetadataResource:Codable,Equatable,Sendable{public let name:String?}
public struct HueAreaResource:Codable,Equatable,Sendable{public let id:HueResourceID;public let type:String;public let metadata:HueMetadataResource?;public let children:[HueResourceReference]}
public struct HueDeviceProductData:Codable,Equatable,Sendable{public let modelID:String?;enum CodingKeys:String,CodingKey{case modelID="model_id"}}
public struct HueDeviceResource:Codable,Equatable,Sendable{public let id:HueResourceID;public let metadata:HueMetadataResource?;public let productData:HueDeviceProductData?;enum CodingKeys:String,CodingKey{case id,metadata;case productData="product_data"}}
public struct HueLightResource:Codable,Equatable,Sendable{
    public struct OnState:Codable,Equatable,Sendable{public let on:Bool}
    public struct DimmingState:Codable,Equatable,Sendable{public let brightness:Double?;public let minimum:Double?;enum CodingKeys:String,CodingKey{case brightness;case minimum="min_dim_level"}}
    public struct ColorState:Codable,Equatable,Sendable{public let xy:HueXY?;public let gamut:HueGamut?}
    public struct TemperatureSchema:Codable,Equatable,Sendable{public let minimum:Int?;public let maximum:Int?;enum CodingKeys:String,CodingKey{case minimum="mirek_minimum";case maximum="mirek_maximum"}}
    public struct TemperatureState:Codable,Equatable,Sendable{public let mirek:Int?;public let valid:Bool?;public let schema:TemperatureSchema?;enum CodingKeys:String,CodingKey{case mirek;case valid="mirek_valid";case schema="mirek_schema"}}
    public struct DynamicsState:Codable,Equatable,Sendable{public let status:String?;public let statusValues:[String]?;enum CodingKeys:String,CodingKey{case status;case statusValues="status_values"}}
    public struct GradientState:Codable,Equatable,Sendable{public let pointsCapable:Int?;enum CodingKeys:String,CodingKey{case pointsCapable="points_capable"}}
    public struct EffectsState:Codable,Equatable,Sendable{public let effectValues:[String]?;enum CodingKeys:String,CodingKey{case effectValues="effect_values"}}
    public struct EffectsV2Action:Codable,Equatable,Sendable{public let effectValues:[String]?;enum CodingKeys:String,CodingKey{case effectValues="effect_values"}}
    public struct EffectsV2State:Codable,Equatable,Sendable{public let action:EffectsV2Action?}
    public let id:HueResourceID;public let owner:HueResourceReference?;public let metadata:HueMetadataResource?;public let on:OnState
    public let dimming:DimmingState?;public let color:ColorState?;public let colorTemperature:TemperatureState?;public let dynamics:DynamicsState?;public let gradient:GradientState?;public let effects:EffectsState?;public let effectsV2:EffectsV2State?;public let mode:String?
    enum CodingKeys:String,CodingKey{case id,owner,metadata,on,dimming,color,dynamics,gradient,effects,mode;case colorTemperature="color_temperature";case effectsV2="effects_v2"}
}
public struct HueSceneResource:Codable,Equatable,Sendable{public let id:HueResourceID;public let group:HueResourceReference?;public let metadata:HueMetadataResource?}

public enum HueInventoryBuilder {
    public static func build(rooms:[HueAreaResource],zones:[HueAreaResource],lights:[HueLightResource],devices:[HueDeviceResource],outputLimits:[HueResourceID:Double]=[:])->[HueArea] {
        let devicesByID=Dictionary(uniqueKeysWithValues:devices.map{($0.id,$0)})
        func baseName(_ r:HueLightResource)->String { r.metadata?.name?.trimmedNonEmpty ?? r.owner.flatMap{devicesByID[$0.resourceID]?.metadata?.name?.trimmedNonEmpty} ?? "Light \(r.id.rawValue.prefix(6))" }
        let counts=Dictionary(grouping:lights,by:baseName).mapValues(\.count)
        let mapped=lights.map { r -> HueLight in
            let base=baseName(r),name=counts[base,default:0]>1 ? "\(base) · \(r.id.rawValue.prefix(4))":base
            let effectValues=r.effectsV2?.action?.effectValues ?? r.effects?.effectValues ?? []
            return .init(id:r.id,ownerID:r.owner?.resourceID,name:name,isOn:r.on.on,brightness:r.dimming?.brightness,color:r.color?.xy,colorTemperatureMirek:r.colorTemperature?.valid == false ? nil:r.colorTemperature?.mirek,dynamicStatus:r.dynamics?.status,gamut:r.color?.gamut,capabilities:.init(power:true,dimming:r.dimming != nil,color:r.color != nil,colorTemperature:r.colorTemperature != nil,dynamicPalette:r.dynamics?.statusValues?.contains("dynamic_palette") == true,gradientPoints:min(max(r.gradient?.pointsCapable ?? 0,0),5),effects:effectValues.filter{!$0.isEmpty},streaming:r.mode == "streaming"),outputLimit:outputLimits[r.id] ?? 100)
        }
        let byID=Dictionary(uniqueKeysWithValues:mapped.map{($0.id,$0)})
        let byOwner=Dictionary(grouping:mapped.compactMap{l in l.ownerID.map{($0,l.id)}},by:\.0).mapValues{$0.map(\.1)}
        return (rooms + zones).compactMap { resource -> HueArea? in
            guard let kind = HueAreaKind(rawValue: resource.type) else { return nil }
            var ids = Set<HueResourceID>()
            for child in resource.children {
                if child.resourceType == "light", byID[child.resourceID] != nil {
                    ids.insert(child.resourceID)
                }
                if child.resourceType == "device" {
                    for id in byOwner[child.resourceID, default: []] { ids.insert(id) }
                }
            }
            let areaLights = mapped
                .filter { ids.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            guard !areaLights.isEmpty else { return nil }
            return HueArea(
                id: resource.id,
                kind: kind,
                name: resource.metadata?.name?.trimmedNonEmpty ?? "Unnamed area",
                lights: areaLights
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
private extension String { var trimmedNonEmpty:String? { let v=trimmingCharacters(in:.whitespacesAndNewlines);return v.isEmpty ? nil:v } }
