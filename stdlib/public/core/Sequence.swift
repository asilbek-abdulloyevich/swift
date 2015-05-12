//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Encapsulates iteration state and interface for iteration over a
/// *sequence*.
///
/// - Note: While it is safe to copy a *generator*, advancing one
///   copy may invalidate the others.
///
/// Any code that uses multiple generators (or `for`...`in` loops)
/// over a single *sequence* should have static knowledge that the
/// specific *sequence* is multi-pass, either because its concrete
/// type is known or because it is constrained to `CollectionType`.
/// Also, the generators must be obtained by distinct calls to the
/// *sequence's* `generate()` method, rather than by copying.
public protocol GeneratorType {
  /// The type of element generated by `self`.
  typealias Element

  /// Advance to the next element and return it, or `nil` if no next
  /// element exists.
  ///
  /// - Requires: `next()` has not been applied to a copy of `self`
  ///   since the copy was made, and no preceding call to `self.next()`
  ///   has returned `nil`.  Specific implementations of this protocol
  ///   are encouraged to respond to violations of this requirement by
  ///   calling `preconditionFailure("...")`.
  mutating func next() -> Element?
}

public protocol _SequenceDefaultsType {
  /// A type that provides the *sequence*'s iteration interface and
  /// encapsulates its iteration state.
  typealias Generator : GeneratorType

  /// Return a *generator* over the elements of this *sequence*.  The
  /// *generator*'s next element is the first element of the
  /// sequence.
  ///
  /// - Complexity: O(1)
  func generate() -> Generator
}

extension _SequenceDefaultsType {
  /// Return a value less than or equal to the number of elements in
  /// `self`, **nondestructively**.
  ///
  /// - Complexity: O(N)
  final public func underestimateCount() -> Int {
    return 0
  }

  final public func _customContainsEquatableElement(
    element: Generator.Element
  ) -> Bool? {
    return nil
  }
}

extension SequenceType {
  /// Return an `Array` containing the elements of `self`,
  /// in order, that satisfy the predicate `includeElement`.
  final public func _prext_filter(
    @noescape includeElement: (Generator.Element) -> Bool
  ) -> [Generator.Element] {
    // Cast away @noescape.
    typealias IncludeElement = (Generator.Element) -> Bool
    let escapableIncludeElement =
      unsafeBitCast(includeElement, IncludeElement.self)
    return Array(lazy(self).filter(escapableIncludeElement))
  }
}

/// This protocol is an implementation detail of `SequenceType`; do
/// not use it directly.
///
/// Its requirements are inherited by `SequenceType` and thus must
/// be satisfied by types conforming to that protocol.
public protocol _Sequence_Type
  : _SequenceDefaultsType {

  /// A type whose instances can produce the elements of this
  /// sequence, in order.
  typealias Generator : GeneratorType

  /// Return a *generator* over the elements of this *sequence*.  The
  /// *generator*'s next element is the first element of the
  /// sequence.
  ///
  /// - Complexity: O(1)
  func generate() -> Generator

  /// Return a value less than or equal to the number of elements in
  /// `self`, **nondestructively**.
  ///
  /// - Complexity: O(N)
  func underestimateCount() -> Int

  /// Return an `Array` containing the results of mapping `transform`
  /// over `self`.
  ///
  /// - Complexity: O(N)
  func _prext_map<T>(
    @noescape transform: (Generator.Element) -> T
  ) -> [T]

  func _customContainsEquatableElement(
    element: Generator.Element
  ) -> Bool?

  /// Return an `Array` containing the elements of `self`,
  /// in order, that satisfy the predicate `includeElement`.
  func _prext_filter(
    @noescape includeElement: (Generator.Element) -> Bool
  ) -> [Generator.Element]
}

/// A type that can be iterated with a `for`...`in` loop.
///
/// `SequenceType` makes no requirement on conforming types regarding
/// whether they will be destructively "consumed" by iteration.  To
/// ensure non-destructive iteration, constrain your *sequence* to
/// `CollectionType`.
public protocol SequenceType : _Sequence_Type {
  /// A type that provides the *sequence*'s iteration interface and
  /// encapsulates its iteration state.
  typealias Generator : GeneratorType

  /// Return a *generator* over the elements of this *sequence*.
  ///
  /// - Complexity: O(1)
  func generate() -> Generator

  /// If `self` is multi-pass (i.e., a `CollectionType`), invoke the function
  /// on `self` and return its result.  Otherwise, return `nil`.
  func ~> <R>(_: Self, _: (_PreprocessingPass, ((Self)->R))) -> R?

  /// Create a native array buffer containing the elements of `self`,
  /// in the same order.
  func ~>(
    _:Self, _: (_CopyToNativeArrayBuffer, ())
  ) -> _ContiguousArrayBuffer<Generator.Element>

  /// Copy a Sequence into an array.
  func ~> (source:Self, ptr:(_InitializeTo, UnsafeMutablePointer<Generator.Element>))
}

extension SequenceType {
  /// Return an `Array` containing the results of mapping `transform`
  /// over `self`.
  ///
  /// - Complexity: O(N)
  final public func _prext_map<T>(
    @noescape transform: (Generator.Element) -> T
  ) -> [T] {
    // Cast away @noescape.
    typealias Transform = (Generator.Element) -> T
    let escapableTransform = unsafeBitCast(transform, Transform.self)
    return Array<T>(lazy(self).map(escapableTransform))
  }
}

public struct _CopyToNativeArrayBuffer {}
public func _copyToNativeArrayBuffer<Args>(args: Args)
  -> (_CopyToNativeArrayBuffer, Args)
{
  return (_CopyToNativeArrayBuffer(), args)
}

/// Return an underestimate of the number of elements in the given
/// sequence, without consuming the sequence.  For Sequences that are
/// actually Collections, this will return x.count()
@availability(*, unavailable, message="call the 'underestimateCount()' method on the sequence")
public func underestimateCount<T : SequenceType>(x: T) -> Int {
  return x.underestimateCount()
}

public struct _InitializeTo {}
internal func _initializeTo<Args>(a: Args) -> (_InitializeTo, Args) {
  return (_InitializeTo(), a)
}

public func ~> <T : _Sequence_Type>(
  source: T, ptr: (_InitializeTo, UnsafeMutablePointer<T.Generator.Element>)) {
  var p = UnsafeMutablePointer<T.Generator.Element>(ptr.1)
  for x in GeneratorSequence(source.generate()) {
    p++.initialize(x)
  }
}

// Operation tags for preprocessingPass.  See Index.swift for an
// explanation of operation tags.
public struct _PreprocessingPass {}

// Default implementation of `_preprocessingPass` for Sequences.  Do not
// use this operator directly; call `_preprocessingPass(s)` instead
public func ~> <
  T : _Sequence_Type, R
>(s: T, _: (_PreprocessingPass, ( (T)->R ))) -> R? {
  return nil
}

internal func _preprocessingPass<Args>(args: Args)
  -> (_PreprocessingPass, Args)
{
  return (_PreprocessingPass(), args)
}

// Pending <rdar://problem/14011860> and <rdar://problem/14396120>,
// pass a GeneratorType through GeneratorSequence to give it "SequenceType-ness"
/// A sequence built around a generator of type `G`.
///
/// Useful mostly to recover the ability to use `for`...`in`,
/// given just a generator `g`:
///
///     for x in GeneratorSequence(g) { ... }
public struct GeneratorSequence<
  G: GeneratorType
> : GeneratorType, SequenceType {

  /// Construct an instance whose generator is a copy of `base`.
  public init(_ base: G) {
    _base = base
  }

  /// Advance to the next element and return it, or `nil` if no next
  /// element exists.
  ///
  /// - Requires: `next()` has not been applied to a copy of `self`
  ///   since the copy was made, and no preceding call to `self.next()`
  ///   has returned `nil`.
  public mutating func next() -> G.Element? {
    return _base.next()
  }

  /// Return a *generator* over the elements of this *sequence*.
  ///
  /// - Complexity: O(1)
  public func generate() -> GeneratorSequence {
    return self
  }

  var _base: G
}

