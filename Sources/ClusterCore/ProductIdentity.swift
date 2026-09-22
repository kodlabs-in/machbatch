public struct ProductIdentity: Equatable, Sendable {
  public let name: String
  public let releaseVersion: String
  public let cliCompatibility: String

  public init(name: String, releaseVersion: String, cliCompatibility: String) {
    self.name = name
    self.releaseVersion = releaseVersion
    self.cliCompatibility = cliCompatibility
  }
}
