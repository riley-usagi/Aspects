public extension TaskAspect {
  
  var phase: ModifiedAspect<Self, TaskPhaseModifier<Success, Never>> {
    modifier(TaskPhaseModifier())
  }
}

public extension ThrowingTaskAspect {
  var phase: ModifiedAspect<Self, TaskPhaseModifier<Success, Error>> {
    modifier(TaskPhaseModifier())
  }
}

public struct TaskPhaseModifier<Success: Sendable, Failure: Error>: AsyncAspectModifier {

  public typealias Base = Task<Success, Failure>
  
  public typealias Produced = AsyncPhase<Success, Failure>
  
  public struct Key: Hashable {}
  
  public var key: Key {
    Key()
  }
  
  public func producer(aspect: some Aspect<Base>) -> AspectProducer<Produced> {
    AspectProducer { context in
      let baseTask = context.transaction { $0.watch(aspect) }
      let task = Task {
        let phase = await AsyncPhase(baseTask.result)
        
        if !Task.isCancelled {
          context.update(with: phase)
        }
      }
      
      context.onTermination = task.cancel
      return .suspending
    }
  }
  
  public func refreshProducer(aspect: some AsyncAspect<Base>) -> AspectRefreshProducer<Produced> {
    AspectRefreshProducer { context in
      let task = await context.transaction { context in
        await context.refresh(aspect)
        return context.watch(aspect)
      }
      
      return await AsyncPhase(task.result)
    }
  }
}
