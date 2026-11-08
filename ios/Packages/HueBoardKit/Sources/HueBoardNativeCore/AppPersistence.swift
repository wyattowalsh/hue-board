import Foundation
import HueBoardKit

public actor AppPersistence {
    public static let shared=AppPersistence()
    private enum Key { static let profile="hue-board.native.profile.v1",selectedArea="hue-board.native.selected-area.v1",sceneRegistry="hue-board.native.scene-registry.v1",restoreJournal="hue-board.native.restore-journal.v1",liveDescriptor="hue-board.native.live-descriptor.v1",liveStatus="hue-board.native.live-status.v1" }
    private let defaults:UserDefaults;private let encoder=JSONEncoder(),decoder=JSONDecoder()
    public init(suiteName:String?=nil){defaults=suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard;encoder.dateEncodingStrategy = .iso8601;decoder.dateDecodingStrategy = .iso8601}
    public func loadProfile()throws->BridgeProfile?{try load(BridgeProfile.self,key:Key.profile)}
    public func saveProfile(_ v:BridgeProfile?)throws{try save(v,key:Key.profile)}
    public func loadSelectedAreaID(bridgeID:String)->HueResourceID?{guard let raw=defaults.dictionary(forKey:Key.selectedArea)?[bridgeID] as? String else{return nil};return .init(rawValue:raw)}
    public func saveSelectedAreaID(_ areaID:HueResourceID?,bridgeID:String){var v=defaults.dictionary(forKey:Key.selectedArea) as? [String:String] ?? [:];v[bridgeID]=areaID?.rawValue;defaults.set(v,forKey:Key.selectedArea)}
    public func sceneID(bridgeID:String,areaID:HueResourceID)->HueResourceID?{let k="\(bridgeID)/\(areaID.rawValue)";guard let raw=defaults.dictionary(forKey:Key.sceneRegistry)?[k] as? String else{return nil};return .init(rawValue:raw)}
    public func saveSceneID(_ sceneID:HueResourceID?,bridgeID:String,areaID:HueResourceID){let k="\(bridgeID)/\(areaID.rawValue)";var v=defaults.dictionary(forKey:Key.sceneRegistry) as? [String:String] ?? [:];v[k]=sceneID?.rawValue;defaults.set(v,forKey:Key.sceneRegistry)}
    public func loadRestoreJournal()throws->RestoreJournal?{try load(RestoreJournal.self,key:Key.restoreJournal)}
    public func saveRestoreJournal(_ v:RestoreJournal?)throws{try save(v,key:Key.restoreJournal)}
    public func loadLiveDescriptor()throws->LiveSessionDescriptor?{try load(LiveSessionDescriptor.self,key:Key.liveDescriptor)}
    public func saveLiveDescriptor(_ v:LiveSessionDescriptor?)throws{try save(v,key:Key.liveDescriptor)}
    public func loadLiveStatus()throws->LiveSessionStatus{try load(LiveSessionStatus.self,key:Key.liveStatus) ?? .idle}
    public func saveLiveStatus(_ v:LiveSessionStatus)throws{try save(v,key:Key.liveStatus)}
    public func clearBridgeState(bridgeID:String)throws{try saveProfile(nil);try saveRestoreJournal(nil);try saveLiveDescriptor(nil);try saveLiveStatus(.idle);var selected=defaults.dictionary(forKey:Key.selectedArea) as? [String:String] ?? [:];selected.removeValue(forKey:bridgeID);defaults.set(selected,forKey:Key.selectedArea);var scenes=defaults.dictionary(forKey:Key.sceneRegistry) as? [String:String] ?? [:];scenes=scenes.filter{!$0.key.hasPrefix("\(bridgeID)/")};defaults.set(scenes,forKey:Key.sceneRegistry)}
    private func load<V:Decodable>(_ t:V.Type,key:String)throws->V?{guard let data=defaults.data(forKey:key) else{return nil};return try decoder.decode(t,from:data)}
    private func save<V:Encodable>(_ v:V?,key:String)throws{if let v{defaults.set(try encoder.encode(v),forKey:key)}else{defaults.removeObject(forKey:key)}}
}
