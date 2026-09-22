import ClusterCore

public struct SinfoRenderer: Sendable {
  public init() {}

  public func render(_ configuration: ClusterConfiguration) -> String {
    let nodeCount = configuration.nodes.count
    let nodeList = compressedNodeList(configuration.nodes.map(\.name))
    return """
      PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
      \(configuration.defaultPartition.name)*       up   infinite      \(nodeCount)   idle \(nodeList)
      """
  }

  private func compressedNodeList(_ names: [String]) -> String {
    guard let first = names.first else { return "" }
    guard names.count > 1 else { return first }
    return "localhost[0-\(names.count - 1)]"
  }
}
