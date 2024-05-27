import SwiftUI

@MainActor public protocol AspectContext {
  
  func read<Node: Aspect>(_ aspect: Node) -> Node.Produced
  
  func set<Node: StateAspect>(_ value: Node.Produced, for aspect: Node)
  
  func modify<Node: StateAspect>(_ aspect: Node, body: (inout Node.Produced) -> Void)
  
  @_disfavoredOverload
  @discardableResult func refresh<Node: AsyncAspect>(_ aspect: Node) async -> Node.Produced
  
  @discardableResult func refresh<Node: Refreshable>(_ aspect: Node) async -> Node.Produced
  
  @_disfavoredOverload func reset<Node: Aspect>(_ aspect: Node)
  
  func reset<Node: Resettable>(_ aspect: Node)
}

public extension AspectContext {
  subscript<Node: StateAspect>(_ aspect: Node) -> Node.Produced {
    get { read(aspect) }
    nonmutating set { set(newValue, for: aspect) }
  }
}

@MainActor public protocol AspectWatchableContext: AspectContext {
  @discardableResult func watch<Node: Aspect>(_ aspect: Node) -> Node.Produced
}
