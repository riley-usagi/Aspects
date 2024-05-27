import Foundation

public protocol ObservableObjectAspect: Aspect where Produced == ObjectType {
  
  associatedtype ObjectType: ObservableObject
  
  @MainActor func object(context: Context) -> ObjectType
}

public extension ObservableObjectAspect {
  var producer: AspectProducer<Produced> {
    AspectProducer { context in
      context.transaction(object)
    } manageValue: { object, context in
      let cancellable = object
        .objectWillChange
        .sink { [weak object] _ in
          // Wait until the object's property is set, because `objectWillChange`
          // emits an event before the property is updated.
          Task { @MainActor in
            if !context.isTerminated, let object {
              context.update(with: object)
            }
          }
        }
      
      context.onTermination = cancellable.cancel
    }
  }
}
