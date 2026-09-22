public struct ProductIdentity: Equatable, Sendable {
  public let name: String
  public let cliCompatibility: String

  public init(name: String, cliCompatibility: String) {
    self.name = name
    self.cliCompatibility = cliCompatibility
  }
}
