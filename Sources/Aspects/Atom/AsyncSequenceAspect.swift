public protocol AsyncSequenceAspect: AsyncAspect where Produced == AsyncPhase<Sequence.Element, Error> {
  associatedtype Sequence: AsyncSequence where Sequence.Element: Sendable
  
  @MainActor func sequence(context: Context) -> Sequence
}

public extension AsyncSequenceAspect {
  var producer: AspectProducer<Produced> {
    AspectProducer { context in
      let sequence = context.transaction(sequence)
      let task = Task {
        do {
          for try await element in sequence {
            if !Task.isCancelled {
              context.update(with: .success(element))
            }
          }
        }
        catch {
          if !Task.isCancelled {
            context.update(with: .failure(error))
          }
        }
      }
      
      context.onTermination = task.cancel
      return .suspending
    }
  }
  
  var refreshProducer: AspectRefreshProducer<Produced> {
    AspectRefreshProducer { context in
      let sequence = context.transaction(sequence)
      let task = Task {
        var phase = Produced.suspending
        
        do {
          for try await element in sequence {
            if !Task.isCancelled {
              phase = .success(element)
            }
          }
        }
        catch {
          if !Task.isCancelled {
            phase = .failure(error)
          }
        }
        
        return phase
      }
      
      context.onTermination = task.cancel
      
      return await withTaskCancellationHandler {
        await task.value
      } onCancel: {
        task.cancel()
      }
    }
  }
}
