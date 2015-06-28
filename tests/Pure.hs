module Main where

import AstPlugin.Internal
import Data.List
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.QuickCheck

main = defaultMain $ testGroup "Pure tests" [
    testProperty "Sentinel value appears on each line" linesContainSentinel
  , testProperty "Names are qualified" namesAreQualified
  ]

linesContainSentinel p m n a =
  sentinel `isInfixOf` format p m n a

namesAreQualified p m n a =
  (p ++ ":" ++ m ++ "." ++ n) `isInfixOf` format p m n a
