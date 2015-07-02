module Main where

import AstPlugin.Internal
import Data.List
import HS2AST.Types
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.QuickCheck

main = defaultMain $ testGroup "Pure tests" [
    testProperty "Sentinel value appears on each line" linesContainSentinel
  , testProperty "Output has ID and AST"               exprHasIdAndAst
  ]

exprHasIdAndAst p m n a = case mkExpr p m n a of
                               Node [id, ast] -> ast == a
                               _              -> False

linesContainSentinel p m n a = sentinel `elem` idLeaves
  where idLeaves = case mkExpr p m n a of
                        Node [Node ls, _] -> map (\(Leaf x) -> x) ls

instance Arbitrary a => Arbitrary (Sexpr a) where
  arbitrary = sizedSexpr 1000

sizedSexpr 0 = fmap Leaf arbitrary
sizedSexpr n = oneof [
    fmap Leaf arbitrary
  , fmap Node (sizedListOf sizedSexpr (n-1))
  ]

-- FIXME: Put this in a library!
sizedListOf gen 0 = return []
sizedListOf gen n = do
  points <- listOf (choose (0, n))
  count  <- arbitrary
  let points' = take (abs count `mod` n) points
      diffs   = diffsOf (sort points')
  mapM gen diffs

diffsOf = diffsOf' 0
  where diffsOf' n [] = []
        diffsOf' n (x:xs) = x - n : diffsOf' x xs
