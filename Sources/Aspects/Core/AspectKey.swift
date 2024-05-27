internal struct AspectKey: Hashable, CustomStringConvertible {
  private let key: AnyHashable
  private let type: ObjectIdentifier
  private let scopeKey: ScopeKey?
  private let anyAspectType: Any.Type
  
  var description: String {
    let aspectLabel = String(describing: anyAspectType)
    
    if let scopeKey {
      return aspectLabel + "-scoped:\(scopeKey)"
    }
    else {
      return aspectLabel
    }
  }
  
  var isScoped: Bool {
    scopeKey != nil
  }
  
  init<Node: Aspect>(_ aspect: Node, scopeKey: ScopeKey?) {
    self.key = AnyHashable(aspect.key)
    self.type = ObjectIdentifier(Node.self)
    self.scopeKey = scopeKey
    self.anyAspectType = Node.self
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(key)
    hasher.combine(type)
    hasher.combine(scopeKey)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.key == rhs.key && lhs.type == rhs.type && lhs.scopeKey == rhs.scopeKey
  }
}
