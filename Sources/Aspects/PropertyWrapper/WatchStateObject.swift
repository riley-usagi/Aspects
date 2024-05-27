import SwiftUI

@propertyWrapper public struct WatchStateObject<Node: ObservableObjectAspect>: DynamicProperty {
  
  @dynamicMemberLookup public struct Wrapper {
    private let object: Node.Produced
    
    public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<Node.Produced, T>) -> Binding<T> {
      Binding(
        get: { object[keyPath: keyPath] },
        set: { object[keyPath: keyPath] = $0 }
      )
    }
    
    fileprivate init(_ object: Node.Produced) {
      self.object = object
    }
  }
  
  private let aspect: Node
  
  @ViewContext private var context
  
  /// Creates an instance with the aspect to watch.
  public init(_ aspect: Node, fileID: String = #fileID, line: UInt = #line) {
    self.aspect = aspect
    self._context = ViewContext(fileID: fileID, line: line)
  }
  
  public var wrappedValue: Node.Produced {
    context.watch(aspect)
  }
  
  public var projectedValue: Wrapper {
    Wrapper(wrappedValue)
  }
}
