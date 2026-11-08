import XCTest
@testable import HueBoardKit

final class SceneBuilderTests:XCTestCase{
 func light(_ id:String,dynamic:Bool=true,streaming:Bool=false,limit:Double=100)->HueLight{.init(id:.init(rawValue:id),ownerID:.init(rawValue:"device-\(id)"),name:id,isOn:true,brightness:50,color:.init(x:0.3,y:0.3),colorTemperatureMirek:nil,gamut:nil,capabilities:.init(power:true,dimming:true,color:true,colorTemperature:false,dynamicPalette:dynamic,streaming:streaming),outputLimit:limit)}
 func testScenePayload()throws{let c=try HueBoardContractLoader.load(),p=try XCTUnwrap(c.preset(id:"ion-eclipse"));let area=HueArea(id:.init(rawValue:"room"),kind:.room,name:"Room",lights:[light("a",limit:80),light("b",limit:55),light("c",dynamic:false),light("d",streaming:true)]);let draft=try HueSceneBuilder.build(area:area,preset:p,contract:c,brightness:90);XCTAssertEqual(draft.animatedLightIDs.map(\.rawValue),["a","b"]);XCTAssertEqual(draft.create.actions.count,2);XCTAssertTrue(draft.create.actions.allSatisfy{$0.action.dimming?.brightness==55});let obj=try JSONSerialization.jsonObject(with:JSONEncoder().encode(draft.create)) as? [String:Any];XCTAssertEqual(obj?["auto_dynamic"] as? Bool,true)}
 func testRejectUnsupported()throws{let c=try HueBoardContractLoader.load(),p=try XCTUnwrap(c.presets.first),area=HueArea(id:.init(rawValue:"r"),kind:.room,name:"R",lights:[light("x",dynamic:false)]);XCTAssertThrowsError(try HueSceneBuilder.build(area:area,preset:p,contract:c,brightness:60))}
}
