import SwiftUI

@propertyWrapper public struct WatchState<Node: StateAspect>: DynamicProperty {
  private let aspect: Node
  
  @ViewContext private var context
  
  public init(_ aspect: Node, fileID: String = #fileID, line: UInt = #line) {
    self.aspect = aspect
    self._context = ViewContext(fileID: fileID, line: line)
  }
  
  public var wrappedValue: Node.Produced {
    get { context.watch(aspect) }
    nonmutating set { context.set(newValue, for: aspect) }
  }
  
  public var projectedValue: Binding<Node.Produced> {
    context.binding(aspect)
  }
}
