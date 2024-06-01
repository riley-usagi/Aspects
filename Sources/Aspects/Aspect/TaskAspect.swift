public protocol TaskAspect: AsyncAspect where Produced == Task<Success, Never> {
  
  associatedtype Success: Sendable
  
  @MainActor func value(context: Context) async -> Success
}

public extension TaskAspect {
  var producer: AspectProducer<Produced> {
    AspectProducer { context in
      Task { [value] in
        await context.transaction(value)
      }
    } manageValue: { task, context in
      context.onTermination = task.cancel
    }
  }
  
  var refreshProducer: AspectRefreshProducer<Produced> {
    AspectRefreshProducer { context in
      Task { [value] in
        await context.transaction(value)
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
