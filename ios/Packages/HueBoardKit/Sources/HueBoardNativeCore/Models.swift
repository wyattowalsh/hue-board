import Foundation
import HueBoardKit

public struct BridgeProfile: Codable, Equatable, Identifiable, Sendable {
    public let bridgeID:String;public let host:String;public let port:Int;public let modelID:String?;public let apiVersion:String?
    public var id:String{bridgeID};public var displayHost:String{port==443 ? host:"\(host):\(port)"}
    public init(bridgeID:String,host:String,port:Int=443,modelID:String?=nil,apiVersion:String?=nil)throws{
        let h=host.trimmingCharacters(in:.whitespacesAndNewlines).lowercased();guard HueBridgeHostValidator.isAllowed(h) else{throw HueBoardError.network("Use a private LAN IPv4 address or trusted .local Hue Bridge hostname.")}
        self.bridgeID=bridgeID.lowercased();self.host=h;self.port=min(max(port,1),65535);self.modelID=modelID;self.apiVersion=apiVersion
    }
}
public struct RestoreJournal:Codable,Equatable,Sendable,Identifiable{
    public let id:UUID;public let bridgeID:String;public let areaID:HueResourceID;public let areaName:String;public let createdAt:Date;public var snapshots:[HueLightSnapshot]
    public init(id:UUID=UUID(),bridgeID:String,area:HueArea,lights:[HueLight],createdAt:Date=Date()){self.id=id;self.bridgeID=bridgeID;areaID=area.id;areaName=area.name;self.createdAt=createdAt;snapshots=lights.map{HueLightSnapshot(light:$0,capturedAt:createdAt)}}
}
public struct LiveSessionDescriptor:Codable,Equatable,Sendable,Identifiable{
    public let id:UUID;public let profile:BridgeProfile;public let areaID:HueResourceID;public let areaKind:HueAreaKind;public let presetID:String;public let brightness:Double;public let duration:TimeInterval;public let startedAt:Date
    public init(id:UUID=UUID(),profile:BridgeProfile,area:HueArea,presetID:String,brightness:Double,duration:TimeInterval,startedAt:Date=Date()){self.id=id;self.profile=profile;areaID=area.id;areaKind=area.kind;self.presetID=presetID;self.brightness=min(max(brightness,5),100);self.duration=min(max(duration,60),3600);self.startedAt=startedAt}
}
public struct LiveSessionStatus:Codable,Equatable,Sendable{
    public enum State:String,Codable,Sendable{case idle,starting,running,completed,cancelled,failed}
    public var sessionID:UUID?;public var state:State;public var progress:Double;public var message:String;public var updatedAt:Date
    public init(sessionID:UUID?,state:State,progress:Double,message:String,updatedAt:Date){self.sessionID=sessionID;self.state=state;self.progress=min(max(progress,0),1);self.message=message;self.updatedAt=updatedAt}
    public static let idle=LiveSessionStatus(sessionID:nil,state:.idle,progress:0,message:"No native Live session is running.",updatedAt:Date())
}
