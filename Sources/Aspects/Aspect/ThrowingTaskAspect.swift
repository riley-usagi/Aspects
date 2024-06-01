public protocol ThrowingTaskAspect: AsyncAspect where Produced == Task<Success, Error> {  
  associatedtype Success: Sendable
  
  @MainActor func value(context: Context) async throws -> Success
}

public extension ThrowingTaskAspect {
  var producer: AspectProducer<Produced> {
    AspectProducer { context in
      Task { [value] in
        try await context.transaction(value)
      }
    } manageValue: { task, context in
      context.onTermination = task.cancel
    }
  }
  
  var refreshProducer: AspectRefreshProducer<Produced> {
    AspectRefreshProducer { context in
      Task { [value] in
        try await context.transaction(value)
      }
    } refreshValue: { task, context in
      context.onTermination = task.cancel
      
      await withTaskCancellationHandler {
        _ = await task.result
      } onCancel: {
        task.cancel()
      }
    }
  }
}
