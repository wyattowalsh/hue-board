import XCTest
@testable import HueBoardKit

final class ContractTests:XCTestCase{
 func testContractSurface()throws{let c=try HueBoardContractLoader.load();XCTAssertEqual(c.schema,1);XCTAssertEqual(c.release,"5.3.0");XCTAssertEqual(c.patterns.count,24);XCTAssertEqual(c.palettes.count,19);XCTAssertEqual(c.presets.count,32);XCTAssertEqual(Set(c.patterns.map(\.id)).count,24);XCTAssertEqual(Set(c.presets.map(\.id)).count,32);XCTAssertTrue(c.presets.allSatisfy{p in c.patterns.contains{$0.id==p.pattern} && c.palettes.contains{$0.index==p.palette}})}
 func testColorsDecode()throws{for p in try HueBoardContractLoader.load().palettes{let colors=try p.decodedColors();XCTAssertEqual(colors.count,4);for v in colors.flatMap(\.components){XCTAssertTrue((0...1).contains(v))}}}
 func testColorMathBounded()throws{let g=HueGamut(red:.init(x:0.675,y:0.322),green:.init(x:0.409,y:0.518),blue:.init(x:0.167,y:0.04));let p=HueColorMath.xy(try RGB(hex:"#35D9BF"),gamut:g);XCTAssertTrue(p.x.isFinite && p.y.isFinite);XCTAssertGreaterThanOrEqual(p.x,0);XCTAssertGreaterThan(p.y,0);XCTAssertLessThanOrEqual(p.x+p.y,1.001)}
}
