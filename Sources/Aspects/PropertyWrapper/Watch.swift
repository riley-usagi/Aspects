import SwiftUI

@propertyWrapper public struct Watch<Node: Aspect>: DynamicProperty {
  private let aspect: Node
  
  @ViewContext private var context
  
  public init(_ aspect: Node, fileID: String = #fileID, line: UInt = #line) {
    self.aspect = aspect
    self._context = ViewContext(fileID: fileID, line: line)
  }
  
  public var wrappedValue: Node.Produced {
    context.watch(aspect)
  }
}
