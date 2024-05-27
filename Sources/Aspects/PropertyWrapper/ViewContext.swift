import SwiftUI

@propertyWrapper public struct ViewContext: DynamicProperty {
  @StateObject private var state = State()
  
  @Environment(\.store) private var _store
  
  private let file: StaticString
  private let location: SourceLocation
  
  public init(file: StaticString = #file, fileID: String = #fileID, line: UInt = #line) {
    self.file = file
    self.location = SourceLocation(fileID: fileID, line: line)
  }
  
  public var wrappedValue: AspectViewContext {
    AspectViewContext(
      store: store,
      subscriber: Subscriber(state.subscriberState),
      subscription: Subscription(
        location: location,
        update: state.objectWillChange.send
      )
    )
  }
}

private extension ViewContext {
  @MainActor final class State: ObservableObject {
    let subscriberState = SubscriberState()
  }
  
  var store: StoreContext {
    guard let _store else {
      assertionFailure(
                """
                [Aspects]
                There is no store provided on the current view tree.
                Make sure that this application has an `AspectRoot` as a root ancestor of any view.
                
                ```
                struct ExampleApp: App {
                    var body: some Scene {
                        WindowGroup {
                            AspectRoot {
                                ExampleView()
                            }
                        }
                    }
                }
                ```
                
                If for some reason the view tree is formed that does not inherit from `EnvironmentValues`,
                consider using `AspectScope` to pass it.
                That happens when using SwiftUI view wrapped with `UIHostingController`.
                
                ```
                struct ExampleView: View {
                    @ViewContext
                    var context
                
                    var body: some View {
                        UIViewWrappingView {
                            AspectScope(inheriting: context) {
                                WrappedView()
                            }
                        }
                    }
                }
                ```
                
                The modal screen presented by the `.sheet` modifier or etc, inherits from the environment values,
                but only in iOS14, there is a bug where the environment values will be dismantled during it is
                dismissing. This also can be avoided by using `AspectScope` to explicitly inherit from it.
                
                ```
                .sheet(isPresented: ...) {
                    AspectScope(inheriting: context) {
                        ExampleView()
                    }
                }
                ```
                """,
                file: file,
                line: location.line
      )
      
      // Returns an ephemeral instance just to not crash in `-O` builds.
      return StoreContext(
        store: AspectStore(),
        scopeKey: ScopeKey(token: ScopeKey.Token()),
        inheritedScopeKeys: [:],
        observers: [],
        scopedObservers: [],
        overrides: [:],
        scopedOverrides: [:]
      )
    }
    
    return _store
  }
}
