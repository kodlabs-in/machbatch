public struct PriorityFactors: Equatable, Codable, Sendable {
  public let age: Int64
  public let association: Int64
  public let fairShare: Int64
  public let jobSize: Int64
  public let partition: Int64
  public let qos: Int64
  public let site: Int64
  public let nice: Int64

  public init(
    age: Int64,
    association: Int64,
    fairShare: Int64,
    jobSize: Int64,
    partition: Int64,
    qos: Int64,
    site: Int64,
    nice: Int64
  ) {
    self.age = age
    self.association = association
    self.fairShare = fairShare
    self.jobSize = jobSize
    self.partition = partition
    self.qos = qos
    self.site = site
    self.nice = nice
  }
}

public struct Priority: Equatable, Sendable {
  public let factors: PriorityFactors
  public let total: Int64
}

public struct PriorityCalculator: Sendable {
  public init() {}

  public func calculate(_ factors: PriorityFactors) -> Priority {
    let positiveFactors = [
      factors.age,
      factors.association,
      factors.fairShare,
      factors.jobSize,
      factors.partition,
      factors.qos,
      factors.site,
    ]
    let total = positiveFactors.reduce(0, +) - factors.nice
    return Priority(factors: factors, total: total)
  }
}
