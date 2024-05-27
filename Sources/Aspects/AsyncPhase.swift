public enum AsyncPhase<Success, Failure: Error> {
  
  case suspending
  
  
  case success(Success)
  
  
  case failure(Failure)
  
  public init(_ result: Result<Success, Failure>) {
    switch result {
    case .success(let value):
      self = .success(value)
      
    case .failure(let error):
      self = .failure(error)
    }
  }
  
  public init(catching body: @Sendable () async throws -> Success) async where Failure == Error {
    do {
      let value = try await body()
      self = .success(value)
    }
    catch {
      self = .failure(error)
    }
  }
  
  public var isSuspending: Bool {
    guard case .suspending = self else {
      return false
    }
    
    return true
  }
  
  public var isSuccess: Bool {
    guard case .success = self else {
      return false
    }
    
    return true
  }
  
  public var isFailure: Bool {
    guard case .failure = self else {
      return false
    }
    
    return true
  }
  
  public var value: Success? {
    guard case .success(let value) = self else {
      return nil
    }
    
    return value
  }
  
  public var error: Failure? {
    guard case .failure(let error) = self else {
      return nil
    }
    
    return error
  }
  
  public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> AsyncPhase<NewSuccess, Failure> {
    flatMap { .success(transform($0)) }
  }
  
  public func mapError<NewFailure>(_ transform: (Failure) -> NewFailure) -> AsyncPhase<Success, NewFailure> {
    flatMapError { .failure(transform($0)) }
  }
  
  public func flatMap<NewSuccess>(_ transform: (Success) -> AsyncPhase<NewSuccess, Failure>) -> AsyncPhase<NewSuccess, Failure> {
    switch self {
    case .suspending:
      return .suspending
      
    case .success(let value):
      return transform(value)
      
    case .failure(let error):
      return .failure(error)
    }
  }
  
  public func flatMapError<NewFailure>(_ transform: (Failure) -> AsyncPhase<Success, NewFailure>) -> AsyncPhase<Success, NewFailure> {
    switch self {
    case .suspending:
      return .suspending
      
    case .success(let value):
      return .success(value)
      
    case .failure(let error):
      return transform(error)
    }
  }
}

extension AsyncPhase: Sendable where Success: Sendable {}
extension AsyncPhase: Equatable where Success: Equatable, Failure: Equatable {}
extension AsyncPhase: Hashable where Success: Hashable, Failure: Hashable {}
