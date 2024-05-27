import SwiftUI

public struct Suspense<Value: Sendable, Failure: Error, Content: View, Suspending: View, FailureContent: View>: View {
  private let task: Task<Value, Failure>
  private let content: (Value) -> Content
  private let suspending: () -> Suspending
  private let failureContent: (Failure) -> FailureContent
  
  @StateObject private var state = State()
  
  public init(
    _ task: Task<Value, Failure>,
    @ViewBuilder content: @escaping (Value) -> Content,
    @ViewBuilder suspending: @escaping () -> Suspending,
    @ViewBuilder catch: @escaping (Failure) -> FailureContent
  ) {
    self.task = task
    self.content = content
    self.suspending = suspending
    self.failureContent = `catch`
  }

  public init(
    _ task: Task<Value, Failure>,
    @ViewBuilder content: @escaping (Value) -> Content
  ) where Suspending == EmptyView, FailureContent == EmptyView {
    self.init(
      task,
      content: content,
      suspending: EmptyView.init,
      catch: { _ in EmptyView() }
    )
  }
  
  public init(
    _ task: Task<Value, Failure>,
    @ViewBuilder content: @escaping (Value) -> Content,
    @ViewBuilder suspending: @escaping () -> Suspending
  ) where FailureContent == EmptyView {
    self.init(
      task,
      content: content,
      suspending: suspending,
      catch: { _ in EmptyView() }
    )
  }
  
  public init(
    _ task: Task<Value, Failure>,
    @ViewBuilder content: @escaping (Value) -> Content,
    @ViewBuilder catch: @escaping (Failure) -> FailureContent
  ) where Suspending == EmptyView {
    self.init(
      task,
      content: content,
      suspending: EmptyView.init,
      catch: `catch`
    )
  }
  
  /// The content and behavior of the view.
  public var body: some View {
    state.task = task
    
    return Group {
      switch state.phase {
      case .success(let value):
        content(value)
        
      case .suspending:
        suspending()
        
      case .failure(let error):
        failureContent(error)
      }
    }
  }
}

private extension Suspense {
  
  @MainActor final class State: ObservableObject {
    
    @Published private(set) var phase = AsyncPhase<Value, Failure>.suspending
    
    private var suspensionTask: Task<Void, Never>? {
      didSet { oldValue?.cancel() }
    }
    
    var task: Task<Value, Failure>? {
      didSet {
        guard task != oldValue else {
          return
        }
        
        guard let task else {
          phase = .suspending
          return suspensionTask = nil
        }
        
        suspensionTask = Task { [weak self] in
          self?.phase = .suspending
          
          let result = await task.result
          
          if !Task.isCancelled {
            self?.phase = AsyncPhase(result)
          }
        }
      }
    }
    
    deinit {
      suspensionTask?.cancel()
    }
  }
}
