public protocol Scoped where Self: Aspect {
  
  associatedtype ScopeID: Hashable = DefaultScopeID
  
  var scopeID: ScopeID { get }
}

public extension Scoped where ScopeID == DefaultScopeID {
  var scopeID: ScopeID {
    DefaultScopeID()
  }
}

public struct DefaultScopeID: Hashable {
  public init() {}
}
