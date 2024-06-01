public protocol ValueAspect: Aspect {
  
  associatedtype Value
  
  @MainActor func value(context: Context) -> Value
}

public extension ValueAspect {
  var producer: AspectProducer<Value> {
    AspectProducer { context in
      context.transaction(value)
    }
  }
}
