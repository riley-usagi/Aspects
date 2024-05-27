public protocol StateAspect: Aspect {
  
  associatedtype Value
  
  @MainActor func defaultValue(context: Context) -> Value
}

public extension StateAspect {
  var producer: AspectProducer<Value> {
    AspectProducer { context in
      context.transaction(defaultValue)
    }
  }
}
