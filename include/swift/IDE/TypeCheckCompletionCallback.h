//===--- TypeCheckCompletionCallback.h  -----------------------------------===//
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
/// \file
/// Provides TypeCheckCompletionCallback implementations for the various kinds
/// of code completion. These extract and persist information needed to compute
/// completion results from the solutions formed during expression typechecking.
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_IDE_TYPECHECKCOMPLETIONCALLBACK_H
#define SWIFT_IDE_TYPECHECKCOMPLETIONCALLBACK_H

#include "swift/AST/Expr.h"
#include "swift/AST/Type.h"
#include "swift/Basic/LLVM.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"

namespace swift {
class Decl;
class DeclContext;
class Type;
class ValueDecl;
class CodeCompletionExpr;

namespace constraints {
class ConstraintSystem;
class Solution;
} // namespace constraints

namespace ide {

class TypeCheckCompletionCallback {
  bool GotCallback = false;

protected:
  /// Subclasses of \c TypeCheckCompletionCallback handle solutions discovered
  /// by the constraint system in this function
  virtual void sawSolutionImpl(const constraints::Solution &solution) = 0;

public:
  virtual ~TypeCheckCompletionCallback() {}

  /// Called for each solution produced while type-checking an expression
  /// that the code completion expression participates in.
  void sawSolution(const constraints::Solution &solution) {
    GotCallback = true;
    sawSolutionImpl(solution);
  };

  /// True if at least one solution was passed via the \c sawSolution
  /// callback.
  bool gotCallback() const { return GotCallback; }

  /// Typecheck the code completion expression in its outermost expression
  /// context, calling \c sawSolution for each solution formed.
  virtual void fallbackTypeCheck(DeclContext *DC);
};

// MARK: - Utility functions for subclasses of TypeCheckCompletionCallback

Type getTypeForCompletion(const constraints::Solution &S, ASTNode Node);

/// If \p E occurs in a pattern matching position, returns the type that it is
/// being pattern-matched against.
/// If that type is an enum, it allows us to suggest the enum cases for the code
/// completion expression \p E.
Type getPatternMatchType(const constraints::Solution &S, Expr *E);

/// Whether the given completion expression is the only expression in its
/// containing closure or function body and its value is implicitly returned.
///
/// If these conditions are met, code completion needs to avoid penalizing
/// completion results that don't match the expected return type when
/// computing type relations, as since no return statement was explicitly
/// written by the user, it's possible they intend the single expression not
/// as the return value but merely the first entry in a multi-statement body
/// they just haven't finished writing yet.
bool isImplicitSingleExpressionReturn(constraints::ConstraintSystem &CS,
                                      Expr *CompletionExpr);

/// Returns \c true iff the decl context \p DC allows calling async functions.
bool isContextAsync(const constraints::Solution &S, DeclContext *DC);

/// Returns true if both types are null or if they are equal.
bool nullableTypesEqual(Type LHS, Type RHS);

} // namespace ide
} // namespace swift

#endif // SWIFT_IDE_TYPECHECKCOMPLETIONCALLBACK_H
