import Foundation

public enum HueBoardContractLoader {
    public static func load() throws -> HueBoardContract { try load(bundle:.module) }
    public static func load(bundle: Bundle) throws -> HueBoardContract {
        guard let url=bundle.url(forResource:"hue-board-contract",withExtension:"json") else { throw HueBoardError.missingResource("The bundled parity contract is missing.") }
        return try JSONDecoder().decode(HueBoardContract.self,from:Data(contentsOf:url))
    }
}
