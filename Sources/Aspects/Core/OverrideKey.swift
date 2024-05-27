@usableFromInline internal struct OverrideKey: Hashable, Sendable {
  private let identifier: Identifier
  
  @usableFromInline init<Node: Aspect>(_ aspect: Node) {
    let key = AnyHashable(aspect.key)
    let type = ObjectIdentifier(Node.self)
    identifier = .node(key: key, type: type)
  }
  
  @usableFromInline init<Node: Aspect>(_: Node.Type) {
    let type = ObjectIdentifier(Node.self)
    identifier = .type(type)
  }
}

private extension OverrideKey {
  enum Identifier: Hashable, @unchecked Sendable {
    case node(key: AnyHashable, type: ObjectIdentifier)
    case type(ObjectIdentifier)
  }
}
