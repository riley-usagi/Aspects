@preconcurrency import Combine

public protocol PublisherAspect: AsyncAspect where Produced == AsyncPhase<Publisher.Output, Publisher.Failure> {
  associatedtype Publisher: Combine.Publisher where Publisher.Output: Sendable
  
  @MainActor func publisher(context: Context) -> Publisher
}

public extension PublisherAspect {
  var producer: AspectProducer<Produced> {
    AspectProducer { context in
      let results = context.transaction(publisher).results
      let task = Task {
        for await result in results {
          if !Task.isCancelled {
            context.update(with: AsyncPhase(result))
          }
        }
      }
      
      context.onTermination = task.cancel
      return .suspending
    }
  }
  
  var refreshProducer: AspectRefreshProducer<Produced> {
    AspectRefreshProducer { context in
      let results = context.transaction(publisher).results
      let task = Task {
        var phase = Produced.suspending
        
        for await result in results {
          if !Task.isCancelled {
            phase = AsyncPhase(result)
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

private extension Publisher {
  var results: AsyncStream<Result<Output, Failure>> {
    AsyncStream { continuation in
      let cancellable = map(Result.success)
        .catch { Just(.failure($0)) }
        .sink(
          receiveCompletion: { _ in
            continuation.finish()
          },
          receiveValue: { result in
            continuation.yield(result)
          }
        )
      
      continuation.onTermination = { termination in
        if case .cancelled = termination {
          cancellable.cancel()
        }
      }
    }
  }
}
